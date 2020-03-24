# frozen_string_literal: true
require_relative 'test_base'
require_relative 'external_saver'
require_relative 'id_pather'
require_src 'external_http'
require 'json'

class CreateTest < TestBase

  def self.id58_prefix
    'v42'
  end

  def id58_setup
    @exercise_name = 'Fizz Buzz'
    @language_name = languages_names.sample
  end

  attr_reader :exercise_name, :language_name

  # - - - - - - - - - - - - - - - - -
  # group_create
  # - - - - - - - - - - - - - - - - -

  test 'w9A', %w(
  |GET /group_create?exercise_names=X&languages_names[]=Y
  |redirects to /kata/group/:id page
  |and a group with :id exists
  ) do
    get '/group_create', {
      exercise_name:exercise_name,
      languages_names:[language_name]
    }
    assert status?(302), status
    follow_redirect!
    assert html_content?, content_type
    url = last_request.url # eg http://example.org/kata/group/xCSKgZ
    assert %r"http://example.org/kata/group/(?<id>.*)" =~ url, url
    assert group_exists?(id), "id:#{id}:" # eg xCSKgZ
    manifest = group_manifest(id)
    assert_equal language_name, manifest['display_name'], manifest
  end

  # - - - - - - - - - - - - - - - - -
  # kata_create
  # - - - - - - - - - - - - - - - - -

  test 'w9B', %w(
  |GET /kata_create?exercise_name=X&language_name=Y
  |redirects to /kata/edit/:id page
  |and a kata with :id exists
  ) do
    get '/kata_create', {
      exercise_name:exercise_name,
      language_name:language_name
    }
    assert status?(302), status
    follow_redirect!
    assert html_content?, content_type
    url = last_request.url # eg http://example.org/kata/edit/H3Nqu2
    assert %r"http://example.org/kata/edit/(?<id>.*)" =~ url, url
    assert kata_exists?(id), "id:#{id}:" # eg H3Nqu2
    manifest = kata_manifest(id)
    assert_equal language_name, manifest['display_name'], manifest
  end

  private

  def group_exists?(id)
    saver.exists?(group_id_path(id))
  end

  def kata_exists?(id)
    saver.exists?(kata_id_path(id))
  end

  include IdPather

  # - - - - - - - - - - - - - - - - - - - -

  def group_manifest(id)
    JSON::parse!(saver.read("#{group_id_path(id)}/manifest.json"))
  end

  def kata_manifest(id)
    JSON::parse!(saver.read("#{kata_id_path(id)}/manifest.json"))
  end

  # - - - - - - - - - - - - - - - - - - - -

  def saver
    ExternalSaver.new(http)
  end

  def http
    ExternalHttp.new
  end

end
