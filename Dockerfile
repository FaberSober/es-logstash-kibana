FROM docker.elastic.co/elasticsearch/elasticsearch:7.9.2
 
ENV VERSION=7.9.2
 
# 安装elasticsearch-analysis-ik分词器
# https://github.com/medcl/elasticsearch-analysis-ik/releases
# ADD https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v${VERSION}/elasticsearch-analysis-ik-$VERSION.zip /tmp/
ADD ./plugins-zip/elasticsearch-analysis-ik-7.9.2.zip /tmp/
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b file:///tmp/elasticsearch-analysis-ik-7.9.2.zip

# 安装elasticsearch-analysis-hanlp-7.5.0分词器
# 目前没有7.9.2匹配版本，安装不成功
# ADD ./plugins-zip/elasticsearch-analysis-hanlp-7.5.0.zip /tmp/
# RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b file:///tmp/elasticsearch-analysis-hanlp-7.5.0.zip

# 安装elasticsearch-analysis-dynamic-synonym同义词插件
# https://github.com/bells/elasticsearch-analysis-dynamic-synonym
ADD ./plugins-zip/elasticsearch-analysis-dynamic-synonym-7.9.2.zip /tmp/
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b file:///tmp/elasticsearch-analysis-dynamic-synonym-7.9.2.zip
 
RUN rm -rf /tmp/*