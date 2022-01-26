# 说明
> es-logstash-kibana的全文检索docker组合，用于快速创建MySQL-logstash-ES同步数据检索。

# 配置logstash同步文件
配置路径：`logstash\pipeline\logstash.conf`

MySQL数据库中需要同步的表，配置查询SQL如下：
```
input {
  jdbc {
    #执行的sql语句
    statement => "SELECT * FROM article"
  }
}
```

配置好MySQL数据库后，启动`docker-compose up`，可以看到拉起了es、logstash、kibana、nginx四个镜像，并且已经实现了MySQL表到ES的同步。

# ElasticSearch的单实例实现

## ES同义词

## logstash
构建注意项：
1. pipeline中只存放conf文件，不要放其他类型的文件，否则会启动报错。

### 动态更新ES的同义词
```
# --------------------- 分词器&同义词 ---------------------
# Step 0: 删除索引
DELETE /smart_talk

# Step 1: 新建索引，配置ik分词器，配置同义词
PUT /smart_talk
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0, 
    "analysis": {
      "analyzer": {
        "ik_syno_smart": {
          "type": "custom",
          "tokenizer": "ik_smart",
          "filter": ["my_stop_filter", "my_remote_syno_filter"],
          "char_filter": "my_char_filter"
        },
        "ik_syno_max_word": {
          "type": "custom",
          "tokenizer": "ik_max_word",
          "filter": ["my_stop_filter", "my_remote_syno_filter"],
          "char_filter": "my_char_filter"
        }
      },
      "filter": {
        "my_stop_filter": {
          "type": "stop",
          "stopwords": [" "]
        },
        "my_remote_syno_filter" : {
          "type" : "dynamic_synonym",
          "synonyms_path" : "http://es-ik-nginx/ikdict/synonym/sysnonyms.txt",
          "interval": 30
        }
      },
      "char_filter": {
        "my_char_filter": {
          "type": "mapping",
          "mappings": ["| => |"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "question": {
        "type": "text",
        "analyzer": "ik_syno_max_word",
        "search_analyzer": "ik_syno_smart"
      },
      "answer": {
        "type": "text",
        "analyzer": "ik_syno_max_word",
        "search_analyzer": "ik_syno_smart"
      }
    }
  }
}

# Step 2: 插入测试数据
PUT /smart_talk/_doc/1
{
  "question": "我每个月怎么充值话费",
  "answer": "每月的账期，我们系统会自动帮您充值相应的话费"
}
PUT /smart_talk/_doc/2
{
  "question": "我的话费怎么返还的",
  "answer": "具体返回的话费，请查看合同规定"
}
PUT /smart_talk/_doc/3
{
  "question": "你们公司的地址在哪里",
  "answer": "我的地址在XXX"
}

# Step 3: 查询测试。更新"http://es-ik-nginx/ikdict/synonym/sysnonyms.txt"文件，可以发现同义词已经实现动态更新
GET /smart_talk/_search
{
  "query": {
    "match": {
      "question": "重置"
    }
  }
}
```

### 本地版本
kibana中同义词测试代码
```
# --------------------- 分词器&同义词 ---------------------
# Step 1: 新建索引，配置ik分词器，配置同义词
PUT /smart_talk
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0, 
    "analysis": {
      "analyzer": {
        "ik_syno_smart": {
          "type": "custom",
          "tokenizer": "ik_smart",
          "filter": ["my_stop_filter", "my_syno_filter"],
          "char_filter": "my_char_filter"
        },
        "ik_syno_max_word": {
          "type": "custom",
          "tokenizer": "ik_max_word",
          "filter": ["my_stop_filter", "my_syno_filter"],
          "char_filter": "my_char_filter"
        }
      },
      "filter": {
        "my_stop_filter": {
          "type": "stop",
          "stopwords": [" "]
        },
        "my_syno_filter": {
          "type": "synonym",
          "synonyms_path": "analysis/synonyms.txt"
        }
      },
      "char_filter": {
        "my_char_filter": {
          "type": "mapping",
          "mappings": ["| => |"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "question": {
        "type": "text",
        "analyzer": "ik_syno_max_word",
        "search_analyzer": "ik_syno_smart"
      },
      "answer": {
        "type": "text",
        "index": false
      }
    }
  }
}

# Step 2: 插入测试数据
PUT /smart_talk/_doc/1
{
  "question": "我每个月怎么充值话费",
  "answer": "每月的账期，我们系统会自动帮您充值相应的话费"
}
PUT /smart_talk/_doc/2
{
  "question": "我的话费怎么返还的",
  "answer": "具体返回的话费，请查看合同规定"
}
PUT /smart_talk/_doc/3
{
  "question": "你们公司的地址在哪里",
  "answer": "我的地址在南京市雨花区南京软件谷华博科技园"
}

# Step 3: 查询测试
GET /smart_talk/_search
{
  "query": {
    "match": {
      "question": "华妃"
    }
  }
}
# Step 4: 手动更新analysis/synonyms.txt文件，新增同义词，查询未起效。重启es服务后，新增的同义词生效
# 优化总结：需要引入同义词热更新策略，暂未找到好用的插件，需要自行修改代码
```

## 新闻搜索
```
GET /med_article/_search
{
  "query": {
    "bool": {
      "must":     { "match": { "state": "2" }},
      "should": [
        {
          "multi_match": {
            "query": "法拍房",
            "fields": ["content", "title", "author"],
            "analyzer": "ik_smart"
          }
        }
      ],
      "minimum_should_match": 1
    }
  },
  "highlight" : {
      "pre_tags" : ["<tag1>", "<tag2>"],
      "post_tags" : ["</tag1>", "</tag2>"],
      "fields" : {
          "content" : {},
          "title" : {},
          "author" : {}
      }
  },
  "sort": [
    {
      "pub_time": {
        "order": "desc"
      }
    }
  ]
}

GET /med_article/_count
{
  "query": {
    "match": {
      "state": "2"
    }
  }
}
```
