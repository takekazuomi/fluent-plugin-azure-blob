module Fluent

require 'fluent/mixin/config_placeholders'

class AzureBlobOutput < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('azureblob', self)

  def initialize
    super
    require 'azure'
    require 'azure_blob_extentions'
    require 'pathname'
    require 'zlib'
    require 'time'
    require 'tempfile'
  end


  config_param :path, :string, :default => ""
  config_param :time_format, :string, :default => nil

  include SetTagKeyMixin
  config_set_default :include_tag_key, false

  include SetTimeKeyMixin
  config_set_default :include_time_key, false

  config_param :storage_account_name, :string, :default => nil
  config_param :storage_access_key, :string, :default => nil
  config_param :storage_blob_host, :string, :default => nil
  config_param :blob_container, :string
  config_param :blob_object_key_format, :string, :default => "%{path}%{time_slice}_%{index}.%{file_extension}"
  config_param :store_as, :string, :default => "gzip"
  config_param :auto_create_container, :bool, :default => true

  attr_reader :container

  include Fluent::Mixin::ConfigPlaceholders

  def placeholders
    [:percent]
  end

  def configure(conf)
    super

    if format_json = conf['format_json']
      @format_json = true
    else
      @format_json = false
    end

    @ext, @mime_type = case @store_as
      when 'gzip' then ['gz', 'application/x-gzip']
      when 'json' then ['json', 'application/json']
      else ['txt', 'text/plain']
    end

    @timef = TimeFormatter.new(@time_format, @localtime)
  end

  def start
    super
    # see: azure-sdk-for-ruby/lib/azure/core/
    Azure.configure do |config|
      config.storage_account_name = @storage_account_name
      config.storage_access_key   = @storage_access_key
    end

    @azure_blob_service = Azure::BlobService.new

    ensure_container
    check_accesskeys
  end

  def format(tag, time, record)
    if @include_time_key || !@format_json
      time_str = @timef.format(time)
    end

    # copied from each mixin because current TimeSlicedOutput can't support mixins.
    if @include_tag_key
      record[@tag_key] = tag
    end
    if @include_time_key
      record[@time_key] = time_str
    end

    if @format_json
      Yajl.dump(record) + "\n"
    else
      "#{time_str}\t#{tag}\t#{Yajl.dump(record)}\n"
    end
  end

  def write(chunk)
    i = 0

    begin
      values_for_blob_object_key = {
        "path" => @path,
        "time_slice" => chunk.key,
        "file_extension" => @ext,
        "index" => i
      }
      blobpath = @blob_object_key_format.gsub(%r(%{[^}]+})) { |expr|
        values_for_blob_object_key[expr[2...expr.size-1]]
      }
      i += 1
    end while @azure_blob_service.blob_exists?(@container.name, blobpath)

    tmp = Tempfile.new("azuleblob-")
    begin
      if @store_as == "gzip"
        w = Zlib::GzipWriter.new(tmp)
        chunk.write_to(w)
        w.close
      else
        chunk.write_to(tmp)
        tmp.close
      end

      $log.debug "tmp.path #{Pathname.new(tmp.path).to_s} -> #{"%s/%s" % [@container.name, blobpath]}"
      
      @azure_blob_service.parallel_upload @container.name, Pathname.new(tmp.path).to_s, blobpath, :in_threads => 2
    ensure
      tmp.close(true) rescue nil
      w.close rescue nil
    end
  end

  private

  def ensure_container
    $log.debug "ensure_container #{@blob_container}"
    $log.debug @blob_container
    @container = @azure_blob_service.get_container_properties(@blob_container)
  rescue Azure::Core::Http::HTTPError
    # 404
    if @auto_create_container
      $log.debug "Creating container #{@blob_container}"
      begin
        @container = @azure_blob_service.create_container(@blob_container)
      rescue Azure::Core::Http::HTTPError => ex
        $log.debug "ensure_container #{@blob_container} :#{ex.message}"
        raise "The specified container does not exist: container = #{@blob_container}"
      end
    end
  end

  def check_accesskeys
    $log.debug "check_accesskeys"

    if(@container.nil?)
      raise "storage_account_name or storage_access_key is invalid. Please check your configuration"
    end
  end

  def blob_object_exists(blobpath)
    $log.debug "blob_object_exists #{blobpath}"
    @azure_blob_service.get_blob_properties(@blob_container, blobpath)
    true
  rescue Azure::Core::Http::HTTPError => ex
    $log.debug "blob_object_exists #{blobpath} :#{ex.message}"
    false
  end
end
end
