#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_request'
require 'puppet/ssl/key'

describe Puppet::SSL::CertificateRequest do
    before do
        @class = Puppet::SSL::CertificateRequest
    end

    it "should be extended with the Indirector module" do
        @class.metaclass.should be_include(Puppet::Indirector)
    end

    it "should indirect certificate_request" do
        @class.indirection.name.should == :certificate_request
    end

    it "should use any provided name as its name" do
        @class.new("myname").name.should == "myname"
    end

    it "should default to the :file terminus" do
        @class.indirection.terminus_class.should == :file
    end

    describe "when managing instances" do
        before do
            @request = @class.new("myname")
        end

        it "should have a name attribute" do
            @request.name.should == "myname"
        end

        it "should have a content attribute" do
            @request.should respond_to(:content)
        end

        it "should be able to read requests from disk" do
            path = "/my/path"
            File.expects(:read).with(path).returns("my request")
            request = mock 'request'
            OpenSSL::X509::Request.expects(:new).with("my request").returns(request)
            @request.read(path).should equal(request)
            @request.content.should equal(request)
        end

        it "should return an empty string when converted to a string with no request" do
            @request.to_s.should == ""
        end

        it "should convert the request to pem format when converted to a string" do
            request = mock 'request', :to_pem => "pem"
            @request.content = request
            @request.to_s.should == "pem"
        end

        it "should have a :to_text method that it delegates to the actual key" do
            real_request = mock 'request'
            real_request.expects(:to_text).returns "requesttext"
            @request.content = real_request
            @request.to_text.should == "requesttext"
        end
    end

    describe "when generating" do
        before do
            @instance = @class.new("myname")

            key = Puppet::SSL::Key.new("myname")
            @key = key.generate

            @request = OpenSSL::X509::Request.new
            OpenSSL::X509::Request.expects(:new).returns(@request)

            @request.stubs(:verify).returns(true)
        end

        it "should use the content of the provided key if the key is a Puppet::SSL::Key instance" do
            key = Puppet::SSL::Key.new("test")
            key.expects(:content).returns @key

            @request.expects(:sign).with{ |key, digest| key == @key }
            @instance.generate(key)
        end

        it "should log that it is creating a new certificate request" do
            Puppet.expects(:info)
            @instance.generate(@key)
        end

        it "should set the subject to [CN, name]" do
            subject = mock 'subject'
            OpenSSL::X509::Name.expects(:new).with([["CN", @instance.name]]).returns(subject)
            @request.expects(:subject=).with(subject)
            @instance.generate(@key)
        end

        it "should set the version to 0" do
            @request.expects(:version=).with(0)
            @instance.generate(@key)
        end

        it "should set the public key to the provided key's public key" do
            # Yay, the private key extracts a new key each time.
            pubkey = @key.public_key
            @key.stubs(:public_key).returns pubkey
            @request.expects(:public_key=).with(@key.public_key)
            @instance.generate(@key)
        end

        it "should sign the csr with the provided key and a digest" do
            digest = mock 'digest'
            OpenSSL::Digest::MD5.expects(:new).returns(digest)
            @request.expects(:sign).with(@key, digest)
            @instance.generate(@key)
        end

        it "should verify the generated request using the public key" do
            @request.expects(:verify).with(@key.public_key)
            @instance.generate(@key)
        end

        it "should fail if verification fails" do
            @request.expects(:verify).returns false

            lambda { @instance.generate(@key) }.should raise_error(Puppet::Error)
        end

        it "should return the generated request" do
            @instance.generate(@key).should equal(@request)
        end

        it "should set its content to the generated request" do
            @instance.generate(@key)
            @instance.content.should equal(@request)
        end
    end
end
