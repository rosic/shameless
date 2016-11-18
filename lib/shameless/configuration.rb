module Shameless
  class Configuration
    attr_accessor :partition_urls, :shards_count, :connection_options, :database_extensions,
      :create_table_options

    attr_accessor :legacy_created_at_is_bigint

    def shards_per_partition_count
      shards_count / partitions_count
    end

    def partitions_count
      partition_urls.count
    end
  end
end
