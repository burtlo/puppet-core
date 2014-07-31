#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../lib/puppettest'

require 'mocha'

class AptPackageProviderTest < PuppetTest::TestCase
    confine "Apt package provider missing" =>
        Puppet::Type.type(:package).provider(:apt).suitable?

	def setup
        super
		@type = Puppet::Type.type(:package)
	end
	
	def test_install
		pkg = @type.create :name => 'faff',
		                   :provider => :apt,
		                   :ensure => :present,
		                   :source => "/tmp/faff.deb"

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
							  '-W',
							  '--showformat',
							  '${Status} ${Package} ${Version}\n',
							  'faff'
					  ).returns(
					        "deinstall ok config-files faff 1.2.3-1\n"
					  ).times(1)

		pkg.provider.expects(
		                 :aptget
		           ).with(
		                 '-q',
		                 '-y',
		                 '-o',
		                 'DPkg::Options::=--force-confold',
		                 :install,
		                 'faff'
					  ).returns(0)
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end
	
	def test_purge
		pkg = @type.create :name => 'faff', :provider => :apt, :ensure => :purged

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
					        '-W',
					        '--showformat',
					        '${Status} ${Package} ${Version}\n',
					        'faff'
					  ).returns(
					        "install ok installed faff 1.2.3-1\n"
					  ).times(1)
		pkg.provider.expects(
		                 :aptget
					  ).with(
					        '-y',
					        '-q',
					        'remove',
					        '--purge',
					        'faff'
					  ).returns(0)
		pkg.provider.expects(
		                 :dpkg
					  ).with(
					        '--purge',
					        'faff'
					  ).returns(0)
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end

	def test_dont_try_to_purge_if_already_purged
		pkg = @type.create :name => 'faff', :provider => :apt, :ensure => :purged

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
					        '-W',
					        '--showformat',
					        '${Status} ${Package} ${Version}\n',
					        'faff'
					  ).raises(
					        Puppet::ExecutionFailure,
					        "No packages found matching faff.\n"
					  ).times(1)
		pkg.provider.expects(
		                 :aptget
					  ).never
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end

	def test_dont_try_to_purge_if_already_purged_and_we_want_it_absent
		pkg = @type.create :name => 'faff', :provider => :apt, :ensure => :absent

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
					        '-W',
					        '--showformat',
					        '${Status} ${Package} ${Version}\n',
					        'faff'
					  ).raises(
					        Puppet::ExecutionFailure,
					        "No packages found matching faff.\n"
					  ).times(1)
		pkg.provider.expects(
		                 :aptget
					  ).never

		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end

	def test_make_sure_we_purge_if_package_still_has_conffiles
		pkg = @type.create :name => 'faff', :provider => :apt, :ensure => :purged

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
					        '-W',
					        '--showformat',
					        '${Status} ${Package} ${Version}\n',
					        'faff'
					  ).returns(
					        "deinstall ok config-files faff 1.2.3-1\n"
					  ).times(1)
		pkg.provider.expects(
		                 :aptget
					  ).with(
					        '-y',
					        '-q',
					        'remove',
					        '--purge',
					        'faff'
					  ).returns(0)
		pkg.provider.expects(
		                 :dpkg
					  ).with(
					        '--purge',
					        'faff'
					  ).returns(0)
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end
	

    def test_latest
		pkg = @type.create :name => 'base-files', :provider => :apt

        assert(pkg, "did not create pkg")
        status = pkg.provider.query
        assert(status, "base-files is not installed")
        assert(status[:ensure] != :absent, "base-files is not installed")

        latest = nil
        assert_nothing_raised("Could not call latest") do
            latest = pkg.provider.latest
        end
        assert(latest, "Could not get latest value from apt")
    end
end

