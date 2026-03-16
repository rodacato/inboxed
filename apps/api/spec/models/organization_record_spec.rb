# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationRecord, type: :model do
  describe "validations" do
    it "validates name presence" do
      org = OrganizationRecord.new(name: nil, slug: "test-slug")
      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("can't be blank")
    end

    it "validates slug presence" do
      org = OrganizationRecord.new(name: "Test", slug: nil)
      expect(org).not_to be_valid
      expect(org.errors[:slug]).to include("can't be blank")
    end

    it "validates slug uniqueness" do
      OrganizationRecord.create!(name: "First", slug: "unique-slug")
      org = OrganizationRecord.new(name: "Second", slug: "unique-slug")
      expect(org).not_to be_valid
      expect(org.errors[:slug]).to include("has already been taken")
    end
  end

  describe "#trial?" do
    it "returns true when trial_ends_at is set" do
      org = OrganizationRecord.new(trial_ends_at: 7.days.from_now)
      expect(org.trial?).to be true
    end

    it "returns false when trial_ends_at is nil" do
      org = OrganizationRecord.new(trial_ends_at: nil)
      expect(org.trial?).to be false
    end
  end

  describe "#permanent?" do
    it "returns true when trial_ends_at is nil" do
      org = OrganizationRecord.new(trial_ends_at: nil)
      expect(org.permanent?).to be true
    end

    it "returns false when trial_ends_at is set" do
      org = OrganizationRecord.new(trial_ends_at: 7.days.from_now)
      expect(org.permanent?).to be false
    end
  end

  describe "#trial_active?" do
    it "returns true when trial has not expired" do
      org = OrganizationRecord.new(trial_ends_at: 7.days.from_now)
      expect(org.trial_active?).to be true
    end

    it "returns false when trial has expired" do
      org = OrganizationRecord.new(trial_ends_at: 1.day.ago)
      expect(org.trial_active?).to be false
    end

    it "returns false when permanent (no trial)" do
      org = OrganizationRecord.new(trial_ends_at: nil)
      expect(org.trial_active?).to be false
    end
  end

  describe "#trial_expired?" do
    it "returns true when trial has expired" do
      org = OrganizationRecord.new(trial_ends_at: 1.day.ago)
      expect(org.trial_expired?).to be true
    end

    it "returns false when trial is still active" do
      org = OrganizationRecord.new(trial_ends_at: 7.days.from_now)
      expect(org.trial_expired?).to be false
    end
  end

  describe "#active?" do
    it "returns true if permanent" do
      org = OrganizationRecord.new(trial_ends_at: nil)
      expect(org.active?).to be true
    end

    it "returns true if trial is active" do
      org = OrganizationRecord.new(trial_ends_at: 7.days.from_now)
      expect(org.active?).to be true
    end

    it "returns false if trial has expired" do
      org = OrganizationRecord.new(trial_ends_at: 1.day.ago)
      expect(org.active?).to be false
    end
  end

  describe "#days_remaining" do
    it "returns nil for permanent orgs" do
      org = OrganizationRecord.new(trial_ends_at: nil)
      expect(org.days_remaining).to be_nil
    end

    it "returns correct number of days for active trial" do
      org = OrganizationRecord.new(trial_ends_at: (7.days + 1.minute).from_now)
      expect(org.days_remaining).to eq(7)
    end

    it "returns 0 for expired trial" do
      org = OrganizationRecord.new(trial_ends_at: 1.day.ago)
      expect(org.days_remaining).to eq(0)
    end
  end
end
