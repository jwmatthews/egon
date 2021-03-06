require 'securerandom'

module Egon
  module Undercloud
    class Commands

      ## OSP7

      def self.OSP7_satellite(satellite_url, org, activation_key)
        return "
        curl -k -O #{satellite_url}/pub/katello-ca-consumer-latest.noarch.rpm
        sudo yum install -y katello-ca-consumer-latest.noarch.rpm
        sudo subscription-manager register --org=\"#{org}\" --activationkey=\"#{activation_key}\"
        #{self.OSP7_no_registration}"
      end
    
      def self.OSP7_vanilla_rhel(rhsm_user, rhsm_password, rhsm_pool_id)
        return "
        sudo subscription-manager register --force --username=\"#{rhsm_user}\" --password=\"#{rhsm_password}\"
        sudo subscription-manager attach --pool=\"#{rhsm_pool_id}\"
        sudo subscription-manager repos --enable=rhel-7-server-rpms \
         --enable=rhel-7-server-optional-rpms --enable=rhel-7-server-extras-rpms \
         --enable=rhel-7-server-openstack-6.0-rpms
        #{self.OSP7_no_registration}"
      end
    
      def self.OSP7_no_registration
        return "
        sudo yum install -y python-rdomanager-oscplugin
        if [ ! -f ~/undercloud.conf ]; then
          cp -f /usr/share/instack-undercloud/undercloud.conf.sample ~/undercloud.conf;
        fi
        #{self.OSP7_no_registration_no_packages}"
      end

      def self.OSP7_no_registration_no_packages
        return OSP7_COMMON
      end

      POST_INSTALL_7 = "
      source ~/stackrc
      source ~/tripleo-undercloud-passwords

      tripleo setup-overcloud-passwords -o ~/tripleo-overcloud-passwords
      source ~/tripleo-overcloud-passwords
      NeutronFlatNetworks=${NeutronFlatNetworks:-'datacentre'}
      NeutronPhysicalBridge=${NeutronPhysicalBridge:-'br-ex'}
      NeutronBridgeMappings=${NeutronBridgeMappings:-'datacentre:br-ex'}
      # Define the interface that will be bridged onto the Neutron defined
      # network.
      NeutronPublicInterface=${NeutronPublicInterface:-nic1}
      HypervisorNeutronPublicInterface=${HypervisorNeutronPublicInterface:-$NeutronPublicInterface}
      NEUTRON_NETWORK_TYPE=${NEUTRON_NETWORK_TYPE:-gre}
      NEUTRON_TUNNEL_TYPES=${NEUTRON_TUNNEL_TYPES:-gre}
      # Define the overcloud libvirt type for virtualization. kvm for
      # baremetal, qemu for an overcloud running in vm's.
      OVERCLOUD_LIBVIRT_TYPE=${OVERCLOUD_LIBVIRT_TYPE:-qemu}
      NtpServer=${NtpServer:-""}
      CONTROLSCALE=${CONTROLSCALE:-1}
      COMPUTESCALE=${COMPUTESCALE:-1}
      CEPHSTORAGESCALE=${CEPHSTORAGESCALE:-0}
      BLOCKSTORAGESCALE=${BLOCKSTORAGESCALE:-0}
      SWIFTSTORAGESCALE=${SWIFTSTORAGESCALE:-0}

      # Default all image parameters to use overcloud-full
      OVERCLOUD_CONTROLLER_IMAGE=${OVERCLOUD_CONTROLLER_IMAGE:-overcloud-full}
      OVERCLOUD_COMPUTE_IMAGE=${OVERCLOUD_COMPUTE_IMAGE:-overcloud-full}
      OVERCLOUD_BLOCKSTORAGE_IMAGE=${OVERCLOUD_BLOCKSTORAGE_IMAGE:-overcloud-full}
      OVERCLOUD_SWIFTSTORAGE_IMAGE=${OVERCLOUD_SWIFTSTORAGE_IMAGE:-overcloud-full}
      OVERCLOUD_CEPHSTORAGE_IMAGE=${OVERCLOUD_CEPHSTORAGE_IMAGE:-overcloud-full}

      # Default flavor parameters
      export OVERCLOUD_CONTROL_FLAVOR=${OVERCLOUD_CONTROL_FLAVOR:-\"baremetal\"}
      export OVERCLOUD_COMPUTE_FLAVOR=${OVERCLOUD_COMPUTE_FLAVOR:-\"baremetal\"}
      export OVERCLOUD_CEPHSTORAGE_FLAVOR=${OVERCLOUD_CEPHSTORAGE_FLAVOR:-\"baremetal\"}
      # Even though we are not deploying nodes with these roles, the templates will
      # still validate that a flavor exists, so just use the baremetal_compute flavor
      # for now.
      export OVERCLOUD_BLOCKSTORAGE_FLAVOR=${OVERCLOUD_BLOCKSTORAGE_FLAVOR:-\"baremetal\"}
      export OVERCLOUD_SWIFTSTORAGE_FLAVOR=${OVERCLOUD_SWIFTSTORAGE_FLAVOR:-\"baremetal\"}

      export OVERCLOUD_RESOURCE_REGISTRY=${OVERCLOUD_RESOURCE_REGISTRY:-\"/usr/share/openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml\"}
      NeutronControlPlaneID=$(neutron net-show ctlplane | grep ' id ' | awk '{print $4}')

      export OVERCLOUD_EXTRA=${OVERCLOUD_EXTRA:-""}

      PLAN_ID=$(tuskar plan-show overcloud | awk '$2==\"uuid\" {print $4}')
      if [ -n \"$PLAN_ID\" ]; then
          tuskar plan-delete $PLAN_ID
      fi

      tuskar plan-create overcloud
      PLAN_ID=$(tuskar plan-show overcloud | awk '$2==\"uuid\" {print $4}')

      CONTROLLER_ID=$(tuskar role-list | awk '$4==\"Controller\" {print $2}')
      COMPUTE_ID=$(tuskar role-list | awk '$4==\"Compute\" {print $2}')
      SWIFT_ID=$(tuskar role-list | awk '$4==\"Swift-Storage\" {print $2}')
      CINDER_ID=$(tuskar role-list | awk '$4==\"Cinder-Storage\" {print $2}')
      CEPH_ID=$(tuskar role-list | awk '$4==\"Ceph-Storage\" {print $2}')

      tuskar plan-add-role $PLAN_ID -r $CONTROLLER_ID
      tuskar plan-add-role $PLAN_ID -r $COMPUTE_ID
      tuskar plan-add-role $PLAN_ID -r $SWIFT_ID
      tuskar plan-add-role $PLAN_ID -r $CINDER_ID
      tuskar plan-add-role $PLAN_ID -r $CEPH_ID

      export TUSKAR_PARAMETERS=${TUSKAR_PARAMETERS:-\"
      -A NeutronControlPlaneID=${NeutronControlPlaneID}
      -A Controller-1::AdminPassword=${OVERCLOUD_ADMIN_PASSWORD}
      -A Controller-1::AdminToken=${OVERCLOUD_ADMIN_TOKEN}
      -A Compute-1::AdminPassword=${OVERCLOUD_ADMIN_PASSWORD}
      -A Controller-1::SnmpdReadonlyUserPassword=${UNDERCLOUD_CEILOMETER_SNMPD_PASSWORD}
      -A Cinder-Storage-1::SnmpdReadonlyUserPassword=${UNDERCLOUD_CEILOMETER_SNMPD_PASSWORD}
      -A Swift-Storage-1::SnmpdReadonlyUserPassword=${UNDERCLOUD_CEILOMETER_SNMPD_PASSWORD}
      -A Compute-1::SnmpdReadonlyUserPassword=${UNDERCLOUD_CEILOMETER_SNMPD_PASSWORD}
      -A Controller-1::CeilometerPassword=${OVERCLOUD_CEILOMETER_PASSWORD}
      -A Controller-1::CeilometerMeteringSecret=${OVERCLOUD_CEILOMETER_SECRET}
      -A Compute-1::CeilometerPassword=${OVERCLOUD_CEILOMETER_PASSWORD}
      -A Compute-1::CeilometerMeteringSecret=${OVERCLOUD_CEILOMETER_SECRET}
      -A Controller-1::CinderPassword=${OVERCLOUD_CINDER_PASSWORD}
      -A Controller-1::GlancePassword=${OVERCLOUD_GLANCE_PASSWORD}
      -A Controller-1::HeatPassword=${OVERCLOUD_HEAT_PASSWORD}
      -A Controller-1::NeutronPassword=${OVERCLOUD_NEUTRON_PASSWORD}
      -A Compute-1::NeutronPassword=${OVERCLOUD_NEUTRON_PASSWORD}
      -A Controller-1::NovaPassword=${OVERCLOUD_NOVA_PASSWORD}
      -A Compute-1::NovaPassword=${OVERCLOUD_NOVA_PASSWORD}
      -A Controller-1::SwiftHashSuffix=${OVERCLOUD_SWIFT_HASH}
      -A Controller-1::SwiftPassword=${OVERCLOUD_SWIFT_PASSWORD}
      -A Controller-1::CinderISCSIHelper=lioadm
      -A Cinder-Storage-1::CinderISCSIHelper=lioadm
      -A Controller-1::CloudName=overcloud
      -A Controller-1::NeutronPublicInterface=$NeutronPublicInterface
      -A Controller-1::NeutronBridgeMappings=$NeutronBridgeMappings
      -A Compute-1::NeutronBridgeMappings=$NeutronBridgeMappings
      -A Controller-1::NeutronFlatNetworks=$NeutronFlatNetworks
      -A Compute-1::NeutronFlatNetworks=$NeutronFlatNetworks
      -A Compute-1::NeutronPhysicalBridge=$NeutronPhysicalBridge
      -A Compute-1::NeutronPublicInterface=$NeutronPublicInterface
      -A Compute-1::NovaComputeLibvirtType=$OVERCLOUD_LIBVIRT_TYPE
      -A Controller-1::NtpServer=${NtpServer}
      -A Compute-1::NtpServer=${NtpServer}
      -A Controller-1::NeutronNetworkType=${NEUTRON_NETWORK_TYPE}
      -A Compute-1::NeutronNetworkType=${NEUTRON_NETWORK_TYPE}
      -A Controller-1::NeutronTunnelTypes=${NEUTRON_TUNNEL_TYPES}
      -A Compute-1::NeutronTunnelTypes=${NEUTRON_TUNNEL_TYPES}
      -A Controller-1::count=${CONTROLSCALE}
      -A Compute-1::count=${COMPUTESCALE}
      -A Swift-Storage-1::count=${SWIFTSTORAGESCALE}
      -A Cinder-Storage-1::count=${BLOCKSTORAGESCALE}
      -A Ceph-Storage-1::count=${CEPHSTORAGESCALE}
      -A Cinder-Storage-1::Flavor=${OVERCLOUD_BLOCKSTORAGE_FLAVOR}
      -A Compute-1::Flavor=${OVERCLOUD_COMPUTE_FLAVOR}
      -A Controller-1::Flavor=${OVERCLOUD_CONTROL_FLAVOR}
      -A Swift-Storage-1::Flavor=${OVERCLOUD_SWIFTSTORAGE_FLAVOR}
      -A Ceph-Storage-1::Flavor=${OVERCLOUD_CEPHSTORAGE_FLAVOR}
      -A Swift-Storage-1::Image=${OVERCLOUD_SWIFTSTORAGE_IMAGE}
      -A Cinder-Storage-1::Image=${OVERCLOUD_BLOCKSTORAGE_IMAGE}
      -A Ceph-Storage-1::Image=${OVERCLOUD_BLOCKSTORAGE_IMAGE}
      -A Controller-1::Image=${OVERCLOUD_CONTROLLER_IMAGE}
      -A Compute-1::Image=${OVERCLOUD_COMPUTE_IMAGE}
      \"}

      if [ $CONTROLSCALE -gt 1 ]; then
          export TUSKAR_PARAMETERS=\"$TUSKAR_PARAMETERS
          -A Controller-1::NeutronL3HA=True
          -A Controller-1::NeutronAllowL3AgentFailover=False
          -A Compute-1::NeutronL3HA=True
          -A Compute-1::NeutronAllowL3AgentFailover=False
          \"
      fi

      if [ $CEPHSTORAGESCALE -gt 0 ]; then
          FSID=$(uuidgen)
          MON_KEY=$(create_cephx_key)
          ADMIN_KEY=$(create_cephx_key)
          CINDER_ISCSI=${CINDER_ISCSI:-0}
          export TUSKAR_PARAMETERS=\"$TUSKAR_PARAMETERS
          -A Controller-1::CinderEnableRbdBackend=True
          -A Controller-1::GlanceBackend=rbd
          -A CephClusterFSID=$FSID
          -A CephMonKey=$MON_KEY
          -A CephAdminKey=$ADMIN_KEY
          -A Compute-1::NovaEnableRbdBackend=True
          \"

          if [ $CINDER_ISCSI -eq 0 ]; then
              export TUSKAR_PARAMETERS=\"$TUSKAR_PARAMETERS
              -A Controller-1::CinderEnableIscsiBackend=false
              \"
          else
              # (this is the default parameter value)
              export TUSKAR_PARAMETERS=\"$TUSKAR_PARAMETERS
                     -A Controller-1::CinderEnableIscsiBackend=true
                     \"
          fi
      fi

      tuskar plan-update $TUSKAR_PARAMETERS $PLAN_ID

      # Added next to parameters as they are required
      TIMEOUT=5
      HEAT_OP=\"stack-create\"

      HEAT_ENV=${HEAT_ENV:-\"overcloud-env.json\"}

      if [ -f $HEAT_ENV -a \"$HEAT_OP\" = \"stack-update\" ]; then
          ENV_JSON=$(cat $HEAT_ENV)
      else
          ENV_JSON='{\"parameters\":{}}'
      fi

      jq . > \"${HEAT_ENV}\" <<< $ENV_JSON
      chmod 0600 \"${HEAT_ENV}\"

      if [ \"$HEAT_OP\" = \"stack-create\" ]; then
        generate-keystone-pki --heatenv $HEAT_ENV
      fi

      KeystoneCACertificate=$(os-apply-config -m $HEAT_ENV --key parameters.KeystoneCACertificate --type raw)
      KeystoneSigningCertificate=$(os-apply-config -m $HEAT_ENV --key parameters.KeystoneSigningCertificate --type raw)
      KeystoneSigningKey=$(os-apply-config -m $HEAT_ENV --key parameters.KeystoneSigningKey --type raw)

      # Sending the Certificates one by one, otherwise there are problems with escaping
      tuskar plan-update -A Controller-1::KeystoneCACertificate=\"${KeystoneCACertificate}\" $PLAN_ID
      tuskar plan-update -A Controller-1::KeystoneSigningCertificate=\"${KeystoneSigningCertificate}\" $PLAN_ID
      tuskar plan-update -A Controller-1::KeystoneSigningKey=\"${KeystoneSigningKey}\" $PLAN_ID

      # Get templates from tuskar
      tuskar plan-templates -O tuskar_templates $PLAN_ID

      OVERCLOUD_YAML_PATH=\"tuskar_templates/plan.yaml\"
      ENVIRONMENT_YAML_PATH=\"tuskar_templates/environment.yaml\"
      "

      OSP7_COMMON = "
      openstack undercloud install
      sudo cp /root/tripleo-undercloud-passwords ~
      sudo chown $USER: ~/tripleo-undercloud-passwords
      sudo cp /root/stackrc ~
      sudo chown $USER: ~/stackrc
      #{POST_INSTALL_7}"

      ## OSP8

      def self.OSP8_satellite(satellite_url, org, activation_key)
        return "
        curl -k -O #{satellite_url}/pub/katello-ca-consumer-latest.noarch.rpm
        sudo yum install -y katello-ca-consumer-latest.noarch.rpm
        sudo subscription-manager register --org=\"#{org}\" --activationkey=\"#{activation_key}\"
        #{self.OSP8_no_registration}"
      end
    
      def self.OSP8_vanilla_rhel(rhsm_user, rhsm_password, rhsm_pool_id)
        return "
        sudo subscription-manager register --force --username=\"#{rhsm_user}\" --password=\"#{rhsm_password}\"
        sudo subscription-manager attach --pool=\"#{rhsm_pool_id}\"
        sudo subscription-manager repos --enable=rhel-7-server-rpms \
         --enable=rhel-7-server-optional-rpms --enable=rhel-7-server-extras-rpms \
         --enable=rhel-7-server-openstack-6.0-rpms
        #{self.OSP8_no_registration}"
      end
    
      def self.OSP8_no_registration
        return "
        sudo yum install -y python-rdomanager-oscplugin
        if [ ! -f ~/undercloud.conf ]; then
          cp -f /usr/share/instack-undercloud/undercloud.conf.sample ~/undercloud.conf;
          sed -i -- 's/#store_events = false/store_events = true/g' ~/undercloud.conf
        fi
        #{self.OSP8_no_registration_no_packages}"
      end

      def self.OSP8_no_registration_no_packages
        return OSP8_COMMON
      end

      POST_INSTALL_8 = "
      sudo setenforce permissive
      source ~/stackrc

      sudo yum install -y rhosp-director-images
      cd /usr/share/rhosp-director-images
      sudo tar xf ironic-python-agent.tar
      sudo tar xf overcloud-full.tar
      openstack overcloud image upload
      cd ~

      SUBNET_ID=$(neutron subnet-show ''  | awk '$2==\"id\" {print $4}')
      neutron subnet-update $SUBNET_ID --dns-nameserver 192.168.122.1

      OS_AUTH_URL_ESC=$(sed 's/\\\//\\\\\\//g' <<<\"$OS_AUTH_URL\")
      sudo yum install -y openstack-tripleo-api
      sudo sed -i -- \"s/#auth_strategy = keystone/auth_strategy = noauth/g\" /etc/tripleo/tripleo.conf
      sudo sed -i -- \"s/#password = <None>/password = $OS_PASSWORD/g\" /etc/tripleo/tripleo.conf
      sudo sed -i -- \"s/#auth_url = http:\\/\\/localhost:35357\\/v2.0/auth_url = $OS_AUTH_URL_ESC/g\" /etc/tripleo/tripleo.conf
      sudo sed -i -- \"s/#identity_uri = <None>/identity_uri = $OS_AUTH_URL_ESC/g\" /etc/tripleo/tripleo.conf
      sudo sed -i -- \"s/#admin_user = <None>/admin_user = admin/g\" /etc/tripleo/tripleo.conf
      sudo sed -i -- \"s/#admin_password = <None>/admin_password = $OS_PASSWORD/g\" /etc/tripleo/tripleo.conf
      sudo service openstack-tripleo-api restart
      sudo systemctl enable openstack-tripleo-api

      sudo sed -i -- \"s/max_json_body_size = 1048576/max_json_body_size = 2000000/g\" /etc/heat/heat.conf
      sudo service openstack-heat-api restart
      sudo service openstack-heat-api-cfn restart
      sudo service openstack-heat-engine restart

      sudo sed -i -- \"s/scheduler_use_baremetal_filters=False/scheduler_use_baremetal_filters=True/g\" /etc/nova/nova.conf
      sudo sed -i -- \"s/#baremetal_scheduler_default_filters/baremetal_scheduler_default_filters/g\" /etc/nova/nova.conf
      sudo service openstack-nova-scheduler restart

      retries=5

      # Temporarily deal with BZ#1319795
      retry_count=0
      while ! systemctl is-active openstack-swift-* >/dev/null && (( retry_count < retries )); do
        echo \"Swift services not started, retrying.\"
        let retry_count+=1; sudo openstack-service restart swift; sleep 60;
      done

      # Swift is not always immediately responsive
      retry_count=0
      while ! swift stat 2>/dev/null && (( $retry_count < $retries )); do
        echo \"Swift is not ready. Sleeping for 30 seconds.\";
        let retry_count+=1; sleep 30;
      done

      if ! swift stat 2>/dev/null; then
        echo \"Swift did not start properly. Please fix the problem before trying again\"
        exit 1
      fi

      if ! [ $(swift list | grep overcloud) ]; then

        cp -r /usr/share/openstack-tripleo-heat-templates .
        cp /usr/share/tripleo-api/templates/capabilities-map.yaml openstack-tripleo-heat-templates/.

        echo '  BlockStorageImage: overcloud-full' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  CephStorageImage: overcloud-full' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  SwiftStorageImage: overcloud-full' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  controllerImage: overcloud-full' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  NovaImage: overcloud-full' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  CinderPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  GlancePassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  SwiftPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  NeutronMetadataProxySharedSecret: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  HeatPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  HeatStackDomainAdminPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  NeutronPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  AdminToken: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  SwiftHashSuffix: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  CeilometerMeteringSecret: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  SnmpdReadonlyUserPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  CeilometerPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  NovaPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  RedisPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml
        echo '  HAProxyStatsPassword: #{SecureRandom.hex}' >> openstack-tripleo-heat-templates/overcloud-resource-registry-puppet.yaml

        echo 'parameter_defaults:' >> openstack-tripleo-heat-templates/environments/deployment_parameters.yaml
        echo '  AdminPassword: changeme' >> openstack-tripleo-heat-templates/environments/deployment_parameters.yaml

        sudo tripleo-plan-create --config-file /etc/tripleo/tripleo.conf
      fi
      "

      OSP8_COMMON = "
      sudo sed -i '/^net.ipv4.ip_forward =/{h;s/=.*/= 1/};${x;/^$/{s//net.ipv4.ip_forward = 1/;H};x}' /etc/sysctl.conf
      sudo sysctl -p /etc/sysctl.conf
      openstack undercloud install
      #{POST_INSTALL_8}"

    end
  end  
end
