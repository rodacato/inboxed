# frozen_string_literal: true

module SiteAdmin
  class BlockedAddressesController < BaseController
    def index
      records = BlockedAddressRecord.order(created_at: :desc)
      render json: {
        data: records.map { |r| serialize(r) }
      }
    end

    def create
      address = params.require(:address).to_s.strip.downcase
      reason = params[:reason]

      if BlockedAddressRecord.exists?(address: address)
        return render json: {error: "already_blocked", message: "Address '#{address}' is already blocked."}, status: :conflict
      end

      record = BlockedAddressRecord.create!(
        address: address,
        reason: reason,
        blocked_by_id: current_user.id
      )

      # Delete existing inboxes matching this address
      deleted_count = delete_matching_inboxes(address)

      render json: {
        data: serialize(record),
        deleted_inboxes: deleted_count
      }, status: :created
    end

    def destroy
      record = BlockedAddressRecord.find(params[:id])
      record.destroy!
      head :no_content
    end

    private

    def serialize(record)
      {
        id: record.id,
        address: record.address,
        reason: record.reason,
        blocked_by_id: record.blocked_by_id,
        created_at: record.created_at.iso8601
      }
    end

    def delete_matching_inboxes(address)
      # Find all inboxes matching this address (exact or wildcard)
      inboxes = if address.include?("*")
        pattern = address.tr("*", "%")
        InboxRecord.where("address LIKE ?", pattern)
      else
        InboxRecord.where(address: address)
      end

      count = inboxes.count
      inboxes.find_each do |inbox|
        Inboxed::Services::DeleteInbox.new.call(inbox_id: inbox.id)
      end
      count
    end
  end
end
