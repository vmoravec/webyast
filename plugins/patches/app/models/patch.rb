require 'resolvable'

# Model for patches available via package kit
class Patch < Resolvable

  private

  # just a short cut for accessing the singleton object
  def self.bm
    BackgroundManager.instance
  end

  # create unique id for the background manager
  def self.id(what)
    "patches_#{what}"
  end

  public

  def to_xml( options = {} )
    super :patch_update, options
  end

  # find patches using PackageKit
  def self.do_find(what, bg_status = nil)
    patch_updates = Array.new
    self.execute("GetUpdates", "NONE", "Package", bg_status) { |line1,line2,line3|
      columns = line2.split ";"
      if what == :available || columns[1] == what
        update = Patch.new(:resolvable_id => columns[1],
                           :kind => line1,
                           :name => columns[0],
                           :arch => columns[2],
                           :repo => columns[3],
                           :summary => line3 )
        return update if columns[1] == what #only the first entry will be returned in a hash
        patch_updates << update
      end
    }
    return patch_updates
  end

  def self.subprocess_find(what)
    # open subprocess
    subproc = IO.popen(subprocess_command what)

    result = nil

    while !subproc.eof? do
      begin
        line = subproc.readline

        unless line.blank?
          received = Hash.from_xml(line)

          # is it a progress or the final list?
          if received.has_key? 'patches'
            Rails.logger.debug "Found #{received['patches'].size} patches"
            result = received['patches']
          elsif received.has_key? 'background_status'
            s = received['background_status']

            bm.update_progress id(what) do |bs|
              bs.status = s['status']
              bs.progress = s['progress']
              bs.subprogress = s['subprogress']
            end
          end
        end
      rescue Exception => e
        Rails.logger.error "Background thread: Could not evaluate output: #{line.chomp}, exception: #{e}"
        Rails.logger.error "Background thread: Backtrace: #{e.backtrace.join("\n")}"

        # rethrow the exception
        raise e
      end
    end

    result
  end


  # find patches
  # Patch.find(:available)
  # Patch.find(:available, :background => true) - read patches in background
  #   the result may the current state (progress) or the actual patch list
  #   call this function in a loop until a patch list (or an error) is received
  # Patch.find(212)
  def self.find(what, opts = {})
    background = opts[:background]

    # background reading doesn't work correctly if class reloading is active
    # (static class members are lost between requests)
    if background && !bm.background_enabled?
      Rails.logger.info "Class reloading is active, cannot use background thread (set config.cache_classes = true)"
      background = false
    end

    if background
      proc_id = id(what)
      if bm.process_finished? proc_id
        Rails.logger.debug "Request #{proc_id} is done"
        return bm.get_value proc_id
      end

      running = bm.get_progress proc_id
      if running
        Rails.logger.debug "Request #{proc_id} is already running: #{running.inspect}"
        return [running]
      end


      bm.add_process proc_id

      Rails.logger.info "Starting background thread for reading patches..."
      # run the patch query in a separate thread
      Thread.new do
        res = subprocess_find what
        Rails.logger.info "*** Patches thread: Found #{res.size} applicable patches"
        bm.finish_process(proc_id, res)
      end

      return [ bm.get_progress(proc_id) ]
    else
      return do_find(what)
    end
  end

  # installs this
  def install
    self.class.install(id)
  end

  # Patch.install(patch)
  # Patch.install(id)
  def self.install(patch)
    if patch.is_a?(Patch)
      update_id = "#{patch.name};#{patch.resolvable_id};#{patch.arch};#{patch.repo}"
      Rails.logger.debug "Install Update: #{update_id}"
      self.package_kit_install(update_id)
    else
      # if is not an object, assume it is an id
      patch_id = patch
      patch = Patch.find(patch_id)
      raise "Can't install update #{patch_id} because it does not exist" if patch.nil? or not patch.is_a?(Patch)
      self.install(patch)
    end
  end

  private

  def self.subprocess_script
    # find the helper script
    script = File.join(RAILS_ROOT, 'vendor/plugin/patches/scripts/list_patches.rb')

    unless File.exists? script
      script = File.join(RAILS_ROOT, '../plugins/patches/scripts/list_patches.rb')

      unless File.exists? script
        raise 'File patches/scripts/list_patches.rb was not found!'
      end
    end

    Rails.logger.debug "Using #{script} script file"
    script
  end

  def self.subprocess_command(what)
    raise "Invalid parameter" if what.to_s.include?("'") or what.to_s.include?('\\')
    ret = "cd #{RAILS_ROOT} && #{File.join(RAILS_ROOT, 'script/runner')} -e #{ENV['RAILS_ENV'] || 'development'} #{subprocess_script}"
    ret += " #{what}" if what != :available
    ret
  end
end
