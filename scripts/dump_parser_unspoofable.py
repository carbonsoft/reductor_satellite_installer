#!/usr/bin/env python
# coding: utf-8

"""
Утилита для разбора XML с единым реестром запрещённых сайтов.
Выдаёт связки URL + ip для проверки сателлитом
"""
import os
import re
import sys
from xml import sax
from urllib import splitport
from urlparse import urlsplit
from itertools import product
from lower_host_lib import pick_host
from carbon_python_utils import DIRS

# pylint: disable=R0902


IP_REGEX = r"^([0-9]{1,3}\.){3}[0-9]{1,3}$"


class DescribedList(list):
    """ Содержит описание списка для человека и префикс для последующего парсера """

    def __init__(self, description, prefix):
        list.__init__(self)
        self.prefix = prefix
        self.description = description

    def printer(self):
        """ prints content of list with prefix, space separated """
        for item in sorted(set(self)):
            print self.prefix, item.encode('utf-8')


class ReductorOutput(object):
    """ Классификатор содержимого реестра в списки редуктора """

    def __init__(self):
        self.urls_http = DescribedList("URLs to block by Host/GET", "url_http")
        self.urls_https = DescribedList("HTTPS URLS for Squid", "url_https")
        self.domains_exact = DescribedList(
            "Any exact domains for DNS block", "domain_exact")
        self.domains_mask = DescribedList(
            "Any masks domains for DNS block", "domain_mask")
        self.domains_proxy = DescribedList(
            "HTTPS Domains for spoof to proxy IP", "domain_proxy")
        self.ip_https = DescribedList(
            "We can block those resources only by IP", "ip_https")
        self.ip_https_plus = DescribedList(
            "We can block those resourses by other ways rather than IP", "ip_https_plus")
        self.ip_block = DescribedList(
            "IP to send to router to full block", "ip_block")
        self.ip_port = DescribedList(
            "IP+ports for any custom protocols", "ip_port")
        self.ports_http = DescribedList(
            "Ports where we need to match http", "port_http")
        self.ports_https = DescribedList(
            "Ports where we need to match https", "port_https")
        self.urls_unknown = DescribedList(
            "URLS that we cant process", "url_unknown")

    def post_process(self):
        """ Дополнительные действия после обработки списков
        1. Заполнение дефолтными значениями
        2. Удаление дубликатов
        3. Отсечение лишнего по логике редиректа в proxy / nginx
        """
        self.__fill_default_ports__()
        for out_list in self.__lists__():
            out_list = sorted(set(out_list))
        tmp = sorted(set(self.domains_proxy) - set(self.domains_exact))
        self.domains_proxy = DescribedList(
            self.domains_proxy.description, self.domains_proxy.prefix)
        self.domains_proxy.extend(tmp)

    def printer(self):
        """ print content of all DescribedLists """
        for out_list in self.__lists__():
            out_list.printer()

    def prefix_list(self):
        """ show list of every prefix we support now """
        for lst in self.__lists__():
            print lst.prefix

    def stats(self):
        """ print sizes of all DescribedLists """
        for lst in self.__lists__():
            print "{0:<15} {1:<7} # {2}".format(lst.prefix, len(set(lst)), lst.description)

    def writer(self, directory=DIRS['lists']):
        """ write content of all lists into files """
        directory += '/rkn'
        if not os.path.isdir(directory):
            os.mkdir(directory)
        for out_list in self.__lists__():
            with open("{0}/rkn.{1}".format(directory, out_list.prefix), 'w') as list_file:
                list_file.write("\n".join(sorted(set(out_list)) + ['']).encode('utf-8'))

    def add_ip_block(self, content):
        """ blocking entire ip on router """
        self.ip_block.extend(content['ip'])

    def add_ip_ftp(self, content):
        """ assume that every FTP link have default 21 port and add it to ip_port """
        self.ip_port.extend("{0} 21".format(ip) for ip in content['ip'])

    def add_domains(self, content):
        """ spoof domains to nginx blackhole """
        for domain in content['domain']:
            if re.match(IP_REGEX, domain):
                self.ip_block.append(domain)
                continue
            if domain.startswith('*.'):
                result = domain.replace('*.', '', 1)
                self.domains_mask.append(result)
                self.urls_http.append(u'http://{0}'.format(result))
            else:
                self.domains_exact.append(domain)
                self.urls_http.append(u'http://{0}'.format(domain))

    def add_ip_port(self, content):
        """ cardsharing etc """
        ports = (self.__pick_port__(url) for url in content['url'])
        pairs = (' '.join(pair) for pair in product(content['ip'], ports))
        self.ip_port.extend(pairs)

    def add_urls(self, content):
        """ процессит URL из имеющегося списка, особое внимание https """
        for url in content['url']:
            port = self.__pick_port__(url)
            proto = url.split(':', 1)[0]
            if proto != 'https':
                continue
            if port:
                url = self.__process_port__(url, proto, port)
            return self.__process_url_https__(content)

    def __lists__(self):
        return (self.__getattribute__(attr) for attr in dir(self)
                if isinstance(self.__getattribute__(attr), DescribedList))

    def __process_port__(self, url, proto, port):
        """ избавляемся от стандартных портов HTTP/HTTPS """
        if {'http': 80, 'https': 443}[proto] == int(port):
            return url.replace(':' + port, '', 1)
        if proto == 'http':
            self.ports_http.append(port)
        else:
            self.ports_https.append(port)
        return url

    def __process_url_https__(self, content):
        """ most magic/complex part of all registry """
        for num, url in enumerate(content['url']):
            port = self.__pick_port__(url)
            proto = url.split(':', 1)[0]
            if port:
                url = self.__process_port__(url, proto, port)
                content['url'][num] = url
        # https://1.2.3.4/wow
        only_ip = all(re.match(IP_REGEX, pick_host(url, 8).split(':')[0]) for url in content['url'])
        if only_ip:
            return
        # https://youtube.com/extremism
        for url in content['url']:
            proto = url.split(':', 1)[0]
            if proto == 'https':
                for domain in content['domain']:
                    for ip in content['ip']:
                        print ip, domain.encode('utf-8'), url.encode('utf-8')

    @staticmethod
    def __pick_port__(url):
        """ Извлечение порта из URL, если нет - вернёт None """
        return splitport(urlsplit(url).netloc)[1]

    def __fill_default_ports__(self):
        self.ports_http.append('80')
        self.ports_https.append('443')


class RKNInfoHandler(sax.ContentHandler):
    """ SAX ContentHandler for EAIS dump only for date """

    def __init__(self):
        sax.ContentHandler.__init__(self)
        self.result = None

    def startElement(self, tag, attributes):
        if tag == 'reg:register':
            self.result = attributes.get('updateTime')
            raise sax.SAXException("everything is fine, we got a data")


class RKNHandler(sax.ContentHandler):
    """ SAX ContentHandler for EAIS dump """

    def __init__(self):
        sax.ContentHandler.__init__(self)
        self.content_types_supported = ("domain", "ip", "url")
        self.content = dict((k, []) for k in self.content_types_supported)
        self.content_type = None
        self.result = ReductorOutput()
        self.attributes = None
        self.current_data = ""

    def process_entry(self):
        """ При необходимости мы можем обработать домены в add_urls,
        ip в add_domains, так что return сразу как только это возможно """
        if self.content['url']:
            return self.result.add_urls(self.content)

    def startElement(self, tag, attributes):
        self.content_type = tag
        if self.content_type == 'content':
            self.attributes = dict(attributes.items())

    def endElement(self, tag):
        if tag in self.content_types_supported:
            if not (self.content_type == 'ip' and not re.match(IP_REGEX, self.current_data)):
                self.content[self.content_type].append(self.current_data)
        elif tag == "content":
            self.process_entry()
            self.content = dict((k, []) for k in self.content_types_supported)
        self.content_type = None
        self.current_data = ""

    def characters(self, content):
        if self.content_type in ("domain", "ip", "url"):
            out = content.strip()
            if not out:
                return
            self.current_data += out


def main_local_dump_date(dump):
    """ получить только дату из начала файла """
    parser = sax.make_parser()
    parser.setFeature(sax.handler.feature_namespaces, 0)
    handler = RKNInfoHandler()
    parser.setContentHandler(handler)
    try:
        parser.parse(dump)
    except sax.SAXException:
        return handler.result


def main(dump, action='printer'):
    """ основной сценарий, когда нужно действительно пройтись по всему реестру """
    parser = sax.make_parser()
    parser.setFeature(sax.handler.feature_namespaces, 0)
    handler = RKNHandler()
    if action == 'prefix_list':
        return handler.result.prefix_list()
    parser.setContentHandler(handler)
    print >> sys.stderr, u'start process dump.xml'
    parser.parse(dump)
    handler.result.post_process()
    if action == 'printer':
        handler.result.printer()
    elif action == 'stats':
        handler.result.stats()
    elif action == 'writer':
        handler.result.writer()
    print >> sys.stderr, u'finished process dump.xml'


if __name__ == "__main__":
    DUMP = DIRS['dump'] + 'dump.xml'
    ACTION = 'stats'
    if len(sys.argv) > 2 and os.path.isfile(sys.argv[1]):
        DUMP = sys.argv[1]
    main(DUMP, 'https_ip')
