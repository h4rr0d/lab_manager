require 'fog'
require 'lab_manager/models/vsphere_config'
require 'connection_pool'

module Providers
  class VSphere
    class << self
      def connect
        @vspehre ||= ConnectionPool.new(size: VSphereConfig.connection_pool.size, timeout: VSphereConfig.connection_pool.timeout) do
          Fog::Compute.new(
            provider: :vsphere,
            vsphere_username: VSphereConfig.username,
            vsphere_password: VSphereConfig.password,
            vsphere_server: VSphereConfig.server,
            vsphere_expected_pubkey_hash: VSphereConfig.expected_pubkey_hash
          )
        end
      end
    end


    # TODO what parameters are mandatory?
    # whould be nice to be able to validate before sendting a request

    def run(template_uid, name, opts)
      opts = opts.reverse_merge(VSphereConfig.run_default_opts)
      VSphere.connect.with do |vs|
        vs.vm_clone(
          'datacenter'    => opts[:datacenter],
          'template_path' => template_uid,
          'name'          => opts[:name],

          'cluster'       => opts[:cluster],
          'linked_clone'  => opts[:linked_clone],
          'dest_folder'   => opts[:dest_folder] || default_dest_folder(opts)
        )
      end
    end

    def default_dest_folder
      # "LabManager/default/#{opts[:lm_meta][:repo]}-#{opts[:lm_meta][:tsd]}"
      # e.g: 'LabManager/%{repoitory}s/%{tsd}s' % opts[:lm_meta]
      opts[:dest_folder_formatter] % opts.merge(opts[:lm_meta])
    end

    def filter_machines_to_be_scheduled(
          queued_machines:  Compute.queued.where(provider: self.to_s),
          alive_machines: Compute.alive.where(provider: self.to_s).order(:created_at)
    )
      queued.machines.limit([0, VSphereConfig.scheduler.max_vm - alive_machines.count].map)
    end
  end
end
