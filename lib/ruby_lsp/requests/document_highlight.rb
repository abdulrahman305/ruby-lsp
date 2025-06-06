# typed: strict
# frozen_string_literal: true

require "ruby_lsp/listeners/document_highlight"

module RubyLsp
  module Requests
    # The [document highlight](https://microsoft.github.io/language-server-protocol/specification#textDocument_documentHighlight)
    # informs the editor all relevant elements of the currently pointed item for highlighting. For example, when
    # the cursor is on the `F` of the constant `FOO`, the editor should identify other occurrences of `FOO`
    # and highlight them.
    #
    # For writable elements like constants or variables, their read/write occurrences should be highlighted differently.
    # This is achieved by sending different "kind" attributes to the editor (2 for read and 3 for write).
    class DocumentHighlight < Request
      #: (GlobalState global_state, (RubyDocument | ERBDocument) document, Hash[Symbol, untyped] position, Prism::Dispatcher dispatcher) -> void
      def initialize(global_state, document, position, dispatcher)
        super()
        char_position, _ = document.find_index_by_position(position)
        delegate_request_if_needed!(global_state, document, char_position)

        node_context = RubyDocument.locate(
          document.ast,
          char_position,
          code_units_cache: document.code_units_cache,
        )

        @response_builder = ResponseBuilders::CollectionResponseBuilder
          .new #: ResponseBuilders::CollectionResponseBuilder[Interface::DocumentHighlight]
        Listeners::DocumentHighlight.new(
          @response_builder,
          node_context.node,
          node_context.parent,
          dispatcher,
          position,
        )
      end

      # @override
      #: -> Array[Interface::DocumentHighlight]
      def perform
        @response_builder.response
      end
    end
  end
end
