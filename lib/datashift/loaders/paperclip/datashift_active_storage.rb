# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     Sept 2012
# License::   MIT. Free, Open Source.
#
# Details::   Module containing common functionality for working with Paperclip attachments
#
require 'logging'

module DataShift

  module ActiveStorage

    include DataShift::Logging

    attr_accessor :attachment

    # Get all files (based on file extensions) from supplied path.
    # Options :
    #     :glob : The glob to use to find files
    # =>  :recursive : Descend tree looking for files rather than just supplied path

    def self.get_files(path, options = {})
      return [path] if File.file?(path)
      glob = options[:glob] ? options[:glob] : '*.*'
      glob = options['recursive'] || options[:recursive] ? "**/#{glob}" : glob

      Dir.glob("#{path}/#{glob}", File::FNM_CASEFOLD)
    end

    def get_file( attachment_path )

      unless File.exist?(attachment_path) && File.readable?(attachment_path)
        logger.error("Cannot process Image from #{Dir.pwd}: Invalid Path #{attachment_path}")
        raise PathError, "Cannot process Image : Invalid Path #{attachment_path}"
      end

      file = begin
        File.new(attachment_path, 'rb')
      rescue StandardError => e
        logger.error(e.inspect)
        raise PathError, "ERROR : Failed to read image from #{attachment_path}"
      end

      file
    end

    # Note the paperclip attachment model defines the storage path via something like :
    # => :path => ":rails_root/public/blah/blahs/:id/:style/:basename.:extension"
    #
    # Options
    #
    #   :attributes
    #
    #     Pass through a hash of attributes to the Paperclip klass's initializer
    #
    #   :has_attached_file_name
    #
    #     The attribute to attach to i.e tPaperclip attachment name defined with macro 'has_attached_file :name'
    #
    #         class Image
    #               has_attached_file :attachment
    #
    #     This is usually called or defaults to  :attachment
    #
    #     e.g
    #       When : has_attached_file :avatar
    #
    #       Give : {:has_attached_file_attribute => :avatar}
    #
    #       When :  has_attached_file :icon
    #
    #       Give : { :has_attached_file_attribute => :icon }
    #
    def create_active_storage_attachment(klass, owner, attachment_path, options = {})

      has_attached_file_attribute = options[:has_attached_file_name] ? options[:has_attached_file_name].to_sym : :attachment

      attachment_file = get_file(attachment_path)
      filename = attachment_path.split('/').last

      paperclip_attributes = { "#{has_attached_file_attribute}": attachment_file }

      paperclip_attributes.merge!(options[:attributes]) if options[:attributes]

      begin
        logger.info("Create paperclip attachment on Class #{klass} - #{paperclip_attributes}")

        #@attachment = klass.new(paperclip_attributes)

        @attachment = Spree::Image.create!(attachment: { io: attachment_file, filename: filename }, viewable: owner)
      rescue StandardError => e
        byebug

        logger.error(e.backtrace.first)
        raise CreateAttachmentFailed, "Failed [#{e.message}] - Creating Attachment [#{attachment_path}] on #{klass}"
      ensure
        attachment_file.close unless attachment_file.closed?
      end
      if @attachment.save
        logger.info("Success: Created Attachment #{@attachment.id} : #{@attachment.attachment_file_name}")

        @attachment
      else
        byebug
        
        logger.error('Problem creating and saving Paperclip Attachment')
        logger.error(@attachment.errors.messages.inspect)
        raise CreateAttachmentFailed, 'PaperClip error - Problem saving Attachment'
      end
    end

  end

end
