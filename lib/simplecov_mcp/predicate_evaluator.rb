# frozen_string_literal: true

module SimpleCovMcp
  # Evaluates coverage predicates from either Ruby code strings or files.
  # Used by the validate subcommand, validate MCP tool, and library API.
  #
  # Security Warning:
  # Predicates execute as arbitrary Ruby code with full system privileges.
  # Only use predicates from trusted sources.
  class PredicateEvaluator
    # Evaluate a predicate from a code string
    #
    # @param code [String] Ruby code that returns a callable (lambda, proc, or object with #call)
    # @param model [CoverageModel] The coverage model to pass to the predicate
    # @return [Boolean] The result of calling the predicate with the model
    # @raise [RuntimeError] If the code doesn't return a callable or has syntax errors
    def self.evaluate_code(code, model)
      # WARNING: The predicate code executes with full Ruby privileges.
      # It has unrestricted access to the file system, network, and system commands.
      # Only use predicate code from trusted sources.
      #
      # We evaluate in a fresh Object context to prevent accidental access to
      # internals, but this provides NO security isolation.
      evaluation_context = Object.new
      predicate = evaluation_context.instance_eval(code, '<predicate>', 1)

      validate_callable(predicate)
      predicate.call(model)
    rescue SyntaxError => e
      raise "Syntax error in predicate code: #{e.message}"
    end

    # Evaluate a predicate from a file
    #
    # @param path [String] Path to Ruby file containing predicate code
    # @param model [CoverageModel] The coverage model to pass to the predicate
    # @return [Boolean] The result of calling the predicate with the model
    # @raise [RuntimeError] If the file doesn't exist, doesn't return a callable, or has syntax errors
    def self.evaluate_file(path, model)
      unless File.exist?(path)
        raise "Predicate file not found: #{path}"
      end

      content = File.read(path)

      # WARNING: The predicate code executes with full Ruby privileges.
      # It has unrestricted access to the file system, network, and system commands.
      # Only use predicate files from trusted sources.
      #
      # We evaluate in a fresh Object context to prevent accidental access to
      # internals, but this provides NO security isolation.
      evaluation_context = Object.new
      predicate = evaluation_context.instance_eval(content, path, 1)

      validate_callable(predicate)
      predicate.call(model)
    rescue SyntaxError => e
      raise "Syntax error in predicate file: #{e.message}"
    end

    # Validate that an object is callable
    #
    # @param predicate [Object] The object to check
    # @raise [RuntimeError] If the object doesn't respond to #call
    def self.validate_callable(predicate)
      unless predicate.respond_to?(:call)
        raise 'Predicate must be callable (lambda, proc, or object with #call method)'
      end
    end
    private_class_method :validate_callable
  end
end
