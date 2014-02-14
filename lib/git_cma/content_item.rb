require 'ostruct'

module GitCma
  # Public: Structured content storage. Uses `Document` for versioning and publishing pipeline support.
  # Content can be any data structure composed of hashes and arrays. It will be accessible through method
  # calls (similar to OpenStruct which it is based on). When saved, content item will serialize the content
  # to JSON and save it. Loading a content item automatically constructs the data structure from the JSON.
  class ContentItem
    attr_reader :document, :id

    def initialize(content, opts = {})
      @document = opts[:document] || Document.new
      @content = if @document.content && !@document.content.empty?
        Content.from_json(@document.content)
      else
        Content.new(content)
      end

      @id = @document.name
    end

    def update(content)
      @content.update(content)
    end

    def delete_field(field)
      @content.delete_field(field)
    end

    def save!(timestamp)
      document.content = @content.to_json
      document.save!(timestamp)

      # index in elastic search
    end

    def load!(rev)
      rev = document.load!(rev)
      @content = Content.from_json(document.content)

      rev
    end

    # Surfacing document API

    def revision
      document.revision
    end

    def history(state = nil, &block)
      document.history(state, &block)
    end

    def promote!(from, to, message, timestamp)
      document.promote!(from, to, message, timestamp)
    end

    def has_been_promoted?(to, rev = nil)
      document.has_been_promoted?(to, rev)
    end

    def rollback!(state)
      document.rollback!(state)
    end

    # Surfacing content

    def [](i)
      @content[i]
    end

    def []=(i, val)
      @content[i] = value
    end

    def method_missing(meth, *args)
      if args.length < 1
        @content.send meth
      elsif args.length == 1
        @content.send meth.chomp("="), *args
      else
        super
      end
    end

    class << self
      def open(id, rev = nil)
        doc = Document.open(id, rev)
        new(nil, document: doc)
      end

      def all(state = 'master')
        # query for all documents in a given state
      end

      def search(query)
        query = {} if query.is_a?(String)

        # talk to elastic search
      end

      private

      def default_mappings
        # id, revision, state, updated_at
      end

      # Internal: idempotently create the ES index
      def ensure_index!
        unless es_client.indices.exists index: 'git-cma-content'
          es_client.indices.create index: 'git-cma-content', body: {mappings: default_mappings}
        end
      end

      def es_client
        @es_client ||= ::Elasticsearch::Client.new log: true
      end
    end
  end
end
