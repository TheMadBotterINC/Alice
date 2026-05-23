#!/usr/bin/env ruby
# Manually add destination_dataset_id column to pipelines table

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE pipelines#{' '}
  ADD COLUMN destination_dataset_id bigint;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE INDEX index_pipelines_on_destination_dataset_id#{' '}
  ON pipelines (destination_dataset_id);
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE pipelines#{' '}
  ADD CONSTRAINT fk_rails_destination_dataset#{' '}
  FOREIGN KEY (destination_dataset_id)#{' '}
  REFERENCES datasets(id);
SQL

puts "Successfully added destination_dataset_id to pipelines table"
