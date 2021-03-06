require 'spec_helper'

describe Revision do
  let(:time) { Time.now }

  let(:document) do
    double(:document).tap do |it|
      allow(it).to receive(:revisions).and_return(revisions)
    end
  end

  let :revisions do
    double(:revisions).tap do |it|
      allow(it).to receive(:root_revision).and_return(root_revision)
    end
  end

  let :revision do
    Revision.new(double(:document), Conent.new({foo: "bar"}), {name: "Author", email: "me@example.com"}, "Saved", time)
  end

  let :root_revision do
    double(:root_revision).tap do |it|
      allow(it).to receive(:id).and_return("root_id")
    end
  end

  it "stores content, author, message and timestamp" do
    revision = Revision.new(document, Content.new({foo: "bar"}), "author", "message", time, "abcdef")

    expect(revision.content.foo).to eq("bar")
    expect(revision.author).to eq("author")
    expect(revision.message).to eq("message")
    expect(revision.timestamp).to eq(time)
  end

  it "takes a commit and can use its id" do
    commit = double(:commit)

    allow(commit).to receive(:is_a?).with(String).and_return(false)
    allow(commit).to receive(:is_a?).with(Rugged::Commit).and_return(true)

    revision = Revision.new(document, Content.new(nil), "author", "message", time, "abcdef", nil, nil, commit)

    expect(commit).to receive(:oid).and_return("id")

    expect(revision.id).to eq("id")
  end

  it "can check it's a root revision" do
    revision = Revision.new(document, Content.new(nil), "author", "message", time, nil)

    allow(revision).to receive(:id).and_return("root_id")
    allow(document.revisions).to receive(:root_revision).and_return(root_revision)

    expect(revision.root?).to eq(true)
  end

  it "can check equality by id" do
    rev1 = Revision.new(document, Content.new(nil), "author", "message 1", time, nil, nil, nil, "id1")
    rev2 = Revision.new(document, Content.new(nil), "author", "message 2", time, nil, nil, nil, "id1")

    expect(rev1).to eq(rev2)
  end

  describe "history links" do
    it "returns previous when set" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev")

      expect(revision.previous).to be_a(Revision)
      expect(revision.previous.id).to eq("prev")
    end

    it "returns previous from a commit" do
      commit = double(:commit).tap do |it|
        allow(it).to receive(:is_a?).with(String).and_return(false)
        allow(it).to receive(:is_a?).with(Rugged::Commit).and_return(true)

        allow(it).to receive(:parent_ids).and_return(['prev'])
      end

      allow(document.revisions).to receive(:root_revision).and_return(root_revision)

      revision = Revision.new(document, nil, nil, nil, nil, nil, nil, nil, commit)

      expect(revision.previous).to be_a(Revision)
      expect(revision.previous.id).to eq("prev")
    end

    it "doesn't return previous if it's root" do
      commit = double(:commit).tap do |it|
        allow(it).to receive(:is_a?).with(String).and_return(false)
        allow(it).to receive(:is_a?).with(Rugged::Commit).and_return(true)

        allow(it).to receive(:parent_ids).and_return(['root_id'])
      end

      allow(document.revisions).to receive(:root_revision).and_return(root_revision)

      revision = Revision.new(document, nil, nil, nil, nil, nil, nil, nil, commit)

      expect(revision.previous).to be_nil
    end

    it "returns nil when origin is not set" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev", nil)

      expect(revision.origin).to be_nil
    end

    it "returns nil when commit doesn't have origin" do
      commit = double(:commit).tap do |it|
        allow(it).to receive(:is_a?).with(String).and_return(false)
        allow(it).to receive(:is_a?).with(Rugged::Commit).and_return(true)

        allow(it).to receive(:parent_ids).and_return(['prev'])
      end

      allow(document.revisions).to receive(:root_revision).and_return(root_revision)

      revision = Revision.new(document, nil, nil, nil, nil, nil, nil, nil, commit)

      expect(revision.origin).to be_nil
    end

    it "returns origin when set" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev", "origin")

      expect(revision.origin).to be_a(Revision)
      expect(revision.origin.id).to eq("origin")
    end

    it "returns origin from a commit" do
      commit = double(:commit).tap do |it|
        allow(it).to receive(:is_a?).with(String).and_return(false)
        allow(it).to receive(:is_a?).with(Rugged::Commit).and_return(true)

        allow(it).to receive(:parent_ids).and_return(['root_id', 'origin'])
      end

      allow(document.revisions).to receive(:root_revision).and_return(root_revision)

      revision = Revision.new(document, nil, nil, nil, nil, nil, nil, nil, commit)

      expect(revision.origin).to be_a(Revision)
      expect(revision.origin.id).to eq("origin")
    end
  end

  describe "history traversal" do
    describe "#has_been_promoted?" do
      let :document do
        Colonel::Document.new({})
      end

      let :draft_revisions do
        m1 = Revision.new(document, Content.new(nil), "author", "message", time, nil)
        m2 = Revision.new(document, Content.new(nil), "author", "message", time, m2)

        {
          'master' => m2
        }
      end

      let :published_revisions do
        m1 = Revision.new(document, Content.new(nil), "author", "message", time, nil, nil, "m1")
        m2 = Revision.new(document, Content.new(nil), "author", "message", time, m1, nil, nil, "m2")
        m3 = Revision.new(document, Content.new(nil), "author", "message", time, m2, nil, nil, "m3")

        p1 = Revision.new(document, Content.new(nil), "author", "message", time, nil, m2, nil, "p1")

        allow(m1).to receive(:commit)
        allow(m2).to receive(:commit)
        allow(m3).to receive(:commit)
        allow(p1).to receive(:commit)

        {
          'master' => m3,
          'published' => p1
        }
      end

      it "returns false for draft only" do
        allow(document).to receive(:revisions).and_return(draft_revisions)

        expect(draft_revisions['master'].has_been_promoted?('published')).to be_falsy
      end

      it "returns true for a later published" do
        allow(document).to receive(:revisions).and_return(published_revisions)

        expect(published_revisions['master'].previous.has_been_promoted?('published')).to be_truthy
      end

      it "returns false for a save over a published one" do
        allow(document).to receive(:revisions).and_return(published_revisions)

        expect(published_revisions['master'].has_been_promoted?('published')).to be_falsy
      end
    end
  end

  describe "lazy loading" do
    it "can create a revision from a sha1 without touching the repository" do
      sha = "abcdef"

      expect(document).not_to receive(:repository)

      rev = Revision.from_commit(document, sha)
      expect(rev.id).to eq("abcdef")
    end

    it "can create a revision from just a sha1 and load the commit for details" do
      sha = "abcdef"
      repo = double(:repository)

      commit = double(:commit).tap do |it|
        allow(it).to receive(:message).and_return("hi")
        allow(it).to receive(:oid).and_return("xyz")
      end

      expect(document).to receive(:repository).and_return(repo)
      expect(repo).to receive(:lookup).with("abcdef").and_return(commit)

      rev = Revision.from_commit(document, sha)

      expect(rev.id).to eq("abcdef") # id from the passed string

      expect(rev.message).to eq("hi")
      expect(rev.id).to eq("xyz") # id from the loaded commit. In reality the two ids will be the same
    end

    # it "loads content from the commit when necessary" - tested through cucumber
  end

  describe "state attribute" do
    it "returns nil when no state was given" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, nil)

      expect(revision.state).to be_nil
    end

    it "keeps state passed when creating a revision" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, nil, nil, 'published')

      expect(revision.state).to eq('published')
    end

    it "passes state on to previous" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev", nil, 'published')

      expect(revision.previous.state).to eq('published')
    end
  end

  describe "type attribute" do
    it "returns 'orphan' when it has no parents" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, nil, nil)

      # this should actually never happen in reality
      expect(revision.type).to eq(:orphan)
    end

    it "returns 'save' when it just has a previous revision" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev", nil)

      expect(revision.type).to eq(:save)
    end

    it "returns 'promotion' when it has previous and origin revisions" do
      revision = Revision.new(document, Content.new(nil), "author", "message", time, "prev", "orig")

      expect(revision.type).to eq(:promotion)
    end
  end
end
