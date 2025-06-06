# typed: true
# frozen_string_literal: true

# NOTE: This module is intended to be used by addons for writing their own tests, so keep that in mind if changing.

module RubyLsp
  # @requires_ancestor: Kernel
  module TestHelper
    class TestError < StandardError; end

    #: [T] (?String? source, ?URI::Generic uri, ?stub_no_typechecker: bool, ?load_addons: bool) { (RubyLsp::Server server, URI::Generic uri) -> T } -> T
    def with_server(source = nil, uri = Kernel.URI("file:///fake.rb"), stub_no_typechecker: false, load_addons: true,
      &block)
      server = RubyLsp::Server.new(test_mode: true)
      server.global_state.apply_options({ initializationOptions: { experimentalFeaturesEnabled: true } })
      server.global_state.instance_variable_set(:@has_type_checker, false) if stub_no_typechecker
      language_id = uri.to_s.end_with?(".erb") ? "erb" : "ruby"

      if source
        server.process_message({
          method: "textDocument/didOpen",
          params: {
            textDocument: {
              uri: uri,
              text: source,
              version: 1,
              languageId: language_id,
            },
          },
        })

        server.global_state.index.index_single(uri, source)
      end

      server.load_addons(include_project_addons: false) if load_addons

      begin
        block.call(server, uri)
      ensure
        if load_addons
          RubyLsp::Addon.addons.each(&:deactivate)
          RubyLsp::Addon.addons.clear
        end
        server.run_shutdown
      end
    end

    #: (RubyLsp::Server server) -> RubyLsp::Result
    def pop_result(server)
      result = server.pop_response
      result = server.pop_response until result.is_a?(RubyLsp::Result) || result.is_a?(RubyLsp::Error)

      if result.is_a?(RubyLsp::Error)
        raise TestError, "Failed to execute request #{result.message}"
      else
        result
      end
    end

    def pop_log_notification(message_queue, type)
      log = message_queue.pop
      return log if log.params.type == type

      log = message_queue.pop until log.params.type == type
      log
    end

    def pop_message(outgoing_queue, &block)
      message = outgoing_queue.pop
      return message if block.call(message)

      message = outgoing_queue.pop until block.call(message)
      message
    end
  end
end
