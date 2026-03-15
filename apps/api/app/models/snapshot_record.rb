class SnapshotRecord < ApplicationRecord
  self.table_name = "snapshots"

  scope :for_stream, ->(name) { where(stream_name: name) }
end
