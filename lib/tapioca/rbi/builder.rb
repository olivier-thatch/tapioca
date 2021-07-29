# typed: strict
# frozen_string_literal: true

module Tapioca
  module RBI
    class Tree
      extend T::Sig

      sig { params(constant: ::Module, block: T.nilable(T.proc.params(scope: Scope).void)).void }
      def create_path(constant, &block)
        constant_name = T.let(::Module.instance_method(:name).bind(constant).call, T.nilable(String))
        raise "given constant does not have a name" unless constant_name

        instance = ::Module.const_get(constant_name)
        case instance
        when ::Class
          create_class(constant.to_s, &block)
        when ::Module
          create_module(constant.to_s, &block)
        else
          raise "unexpected type: #{constant_name} is a #{instance.class}"
        end
      end

      sig { params(name: String, block: T.nilable(T.proc.params(scope: Scope).void)).void }
      def create_module(name, &block)
        node = create_node(Module.new(name))
        block&.call(T.cast(node, Scope))
      end

      sig do
        params(
          name: String,
          superclass_name: T.nilable(String),
          block: T.nilable(T.proc.params(scope: Scope).void)
        ).void
      end
      def create_class(name, superclass_name: nil, &block)
        node = create_node(Class.new(name, superclass_name: superclass_name))
        block&.call(T.cast(node, Scope))
      end

      sig { params(name: String, value: String).void }
      def create_constant(name, value:)
        create_node(Const.new(name, value))
      end

      sig { params(name: String).void }
      def create_include(name)
        create_node(Include.new(name))
      end

      sig { params(name: String).void }
      def create_extend(name)
        create_node(Extend.new(name))
      end

      sig { params(name: String).void }
      def create_mixes_in_class_methods(name)
        create_node(MixesInClassMethods.new(name))
      end

      sig { params(name: String, value: String).void }
      def create_type_member(name, value: "type_member")
        create_node(TypeMember.new(name, value))
      end

      sig do
        params(
          name: String,
          parameters: T::Array[TypedParam],
          return_type: String,
          class_method: T::Boolean
        ).void
      end
      def create_method(name, parameters: [], return_type: "T.untyped", class_method: false)
        return unless valid_method_name?(name)

        sig = RBI::Sig.new(return_type: return_type)
        method = RBI::Method.new(name, sigs: [sig], is_singleton: class_method)
        parameters.each do |param|
          method << param.param
          sig << RBI::SigParam.new(param.param.name, param.type)
        end
        self << method
      end

      private

      SPECIAL_METHOD_NAMES = T.let(
        ["!", "~", "+@", "**", "-@", "*", "/", "%", "+", "-", "<<", ">>", "&", "|", "^", "<", "<=", "=>", ">", ">=",
         "==", "===", "!=", "=~", "!~", "<=>", "[]", "[]=", "`"].freeze,
        T::Array[String]
      )

      sig { params(name: String).returns(T::Boolean) }
      def valid_method_name?(name)
        return true if SPECIAL_METHOD_NAMES.include?(name)
        !!name.match(/^[a-zA-Z_][[:word:]]*[?!=]?$/)
      end

      sig { returns(T::Hash[String, Node]) }
      def nodes_cache
        T.must(@nodes_cache ||= T.let({}, T.nilable(T::Hash[String, Node])))
      end

      sig { params(node: Node).returns(Node) }
      def create_node(node)
        cached = nodes_cache[node.to_s]
        return cached if cached
        nodes_cache[node.to_s] = node
        self << node
        node
      end
    end

    class TypedParam < T::Struct
      const :param, RBI::Param
      const :type, String
    end
  end
end