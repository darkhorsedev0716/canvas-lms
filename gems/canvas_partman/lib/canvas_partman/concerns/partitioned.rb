module CanvasPartman::Concerns
  # Mix into a model to enforce partitioning behavior.
  #
  # @warn
  #  Normal CRUD operations will no longer work on the master table once a model
  #  becomes Partitioned; you are responsible for maintaining a valid partition
  #  for *every* record you try to create or modify.
  module Partitioned
    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        cattr_accessor :partitioning_field
        cattr_accessor :partitioning_interval
        cattr_accessor :partitioning_schema_builder

        self.partitioning_field = 'created_at'
        self.partitioning_interval = :months
      end
    end

    module ClassMethods
      def partitioned(opts={}, &schema_builder)
        self.partitioning_field = opts[:on].to_s if opts[:on]
        self.partitioning_interval = opts[:over].to_sym if opts[:over]

        if schema_builder.present?
          self.partitioning_schema_builder = schema_builder
        end
      end

      # :nodoc:
      #
      # @override ActiveRecord::Persistence#unscoped
      # @see CanvasPartman::DynamicRelation
      # @internal
      #
      # Monkey patch the relation we'll use for queries.
      def unscoped
        super.tap do |relation|
          relation.send :extend, CanvasPartman::DynamicRelation
        end
      end

      # :nodoc:
      def arel_table_from_key_values(attributes)
        partition_table_name = infer_partition_table_name(attributes)

        @arel_tables ||= {}
        @arel_tables[partition_table_name] ||= begin
          Arel::Table.new(partition_table_name, { engine: self.arel_engine })
        end
      end

      # @internal
      #
      # Come up with the table name for the partition the record with the given
      # attribute pairs should be placed in.
      #
      # @param [Array<Array<String, Mixed>>] attributes
      #  Attribute pairs the model is being created/updated with. You can use
      #  these to infer the partition name, e.g, based on :created_at.
      #
      # @return [String]
      #  The table name for the partition.
      def infer_partition_table_name(attributes)
        date_attr = attributes.detect { |(k,v)| k.name == partitioning_field }

        if date_attr.nil? || date_attr[1].nil?
          raise ArgumentError.new <<-ERROR
            Partition resolution failure!!!
            Expected "#{partitioning_field}" attribute to be present in set and
            have a value, but was or did not:

            #{attributes}
          ERROR
        end

        date = date_attr[1]

        case partitioning_interval
        when :months
          [ self.table_name, date.year, date.month ].join('_')
        when :years
          [ self.table_name, date.year ].join('_')
        else
          raise NotImplementedError.new <<-ERROR
            Only [:months,:years] are currently supported as a partitioning
            interval.
          ERROR
        end
      end

      # :nodoc:
      def partitioned?
        true
      end
    end
  end
end