require 'fileutils'

When(/^I dump documents into a file named "(.*?)"$/) do |filename|
  index = DocumentIndex.new(Colonel.config.storage_path)
  docs = index.documents.map { |doc| Document.open(doc[:name]) }

  File.open(filename, "w") do |f|
    Serializer.generate(docs, f)
  end
end

When(/^I remove all files in the storage$/) do
  FileUtils.rm_rf Colonel.config.storage_path
end

When(/^I restore documents from a file named "(.*?)"$/) do |filename|
  File.open(filename, "r") do |f|
    Serializer.load(f)
  end
end

When(/^I list all documents in the document index$/) do
  index = DocumentIndex.new(Colonel.config.storage_path)
  @documents = index.documents.map do |doc|
    type = DocumentType.get(doc[:type])
    type.open(doc[:name])
  end
end

When(/^I recreate the Elasticsearch index$/) do
  ElasticsearchProvider.es_client.indices.delete index: Colonel.config.index_name
  ElasticsearchProvider.initialize!
end

When(/^I reindex the documents$/) do
  index = DocumentIndex.new(Colonel.config.storage_path)
  documents = index.documents.map do |doc|
    type = DocumentType.get(doc[:type])
    type.open(doc[:name])
  end

  Indexer.index(documents)

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

When(/^I reindex the "(.*?)" documents$/) do |klass|
  klass = Object.const_get(klass)

  index = DocumentIndex.new(Colonel.config.storage_path)
  documents = index.documents.map do |doc|
    type = DocumentType.get(doc[:type])
    type.open(doc[:name])
  end

  Indexer.index(documents)

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end
