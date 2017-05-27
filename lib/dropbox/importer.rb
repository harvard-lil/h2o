class Dropbox::Importer
  FAILED_DIR_FILE_PATH = '/failed'
  def logger
    Rails.logger
  end

  attr_reader :bulk_upload

  def initialize(dh2o)
    @dh2o = dh2o
  end

  def import(klass, bulk_upload)
    logger.debug "dropbox_importer.rb (19): Import message received with KLASS: #{klass.inspect} BULK_UPLOAD: #{bulk_upload.inspect}"
    @klass = klass
    @bulk_upload = bulk_upload
    paths_to_import.each do |path|
      logger.debug "dropbox_importer.rb (23): Import for #{path} started"
      import!(path)
      logger.debug "dropbox_importer.rb (25): Import for #{path} finished"
    end
    handle_dupes
    self.bulk_upload
  end

  def import!(path)
    logger.debug "dropbox_importer.rb (32): import! message received with PATH: #{path.inspect}"

    unless path =~ /\.xml$/
      logger.debug "dropbox_importer.rb (32): not XML, skipping path"
      return
    end

    new_instance = build_instance(path)

    logger.debug "dropbox_importer.rb (34): new instance built for #{path.inspect}"
    if new_instance.save
      logger.info "dropbox_importer.rb (36): new instance saved successfully"
      handle_import_success(path, new_instance)
    else
      logger.error "dropbox_importer.rb (39): new instance save failed"
      logger.error new_instance.errors.inspect
      handle_import_error(path, new_instance)
    end
  end

  def build_instance(path)
    file_contents = @dh2o.get_file(path)
    begin
      new_instance = @klass.new_from_xml_file(file_contents)
      new_instance.public = false
    rescue Exception => e
      Import.create!(:dropbox_filepath => e.message)
    end
    new_instance
  end

  def handle_import_success(path, new_instance)
    logger.debug "dropbox_importer.rb (55): handle_import_success message received PATH: #{path.inspect} NEWINSTANCE: #{new_instance.inspect}"
    record_import(:bulk_upload => self.bulk_upload,
                  :actual_object => new_instance,
                  :dropbox_filepath => path,
                  :status => 'Object Created')
  end

  def handle_import_error(path, new_instance)
    logger.error "dropbox_importer.rb (64): handle_import_error message received PATH: #{path.inspect} NEWINSTANCE: #{new_instance.inspect}"
    logger.error "file didn't save"
    self.bulk_upload.update_attribute('has_errors', true)
    @dh2o.copy_to_failed_dir(path)
    record_import(:bulk_upload => self.bulk_upload,
                  :dropbox_filepath => path,
                  :status => 'Errored')
  end

  def handle_dupes
    self.paths_of_dupes.each do |path|
      logger.debug "Dupe recorded"
      record_import(:bulk_upload => self.bulk_upload,
                    :dropbox_filepath => path,
                    :status => 'Dupe Detected')
    end

  end

  def copy_to_failed_dir(path)
    @dh2o.copy_to_dir(FAILED_DIR_FILE_PATH, path)
  end

  def import_file_paths
    res = @dh2o.file_paths
    res = res - excluded_file_paths
    res
  end

  def excluded_file_paths
    [FAILED_DIR_FILE_PATH,
     '/parser_archive',
     '/parser_input',
     '/parser_output']
  end

  def record_import(options = {})
    Import.create!(options)
  end

  def paths_to_import
    @paths_to_import ||= (@dh2o.file_paths - paths_already_imported)
  end

  def paths_of_dupes
    @paths_of_dupes ||= (@dh2o.file_paths - self.paths_to_import)
  end

  def paths_already_imported
    @paths_already_imported ||= Import.completed_paths(@klass)
  end
end
