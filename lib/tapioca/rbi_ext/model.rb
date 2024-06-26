# typed: strict
# frozen_string_literal: true

module RBI
  class Tree
    extend T::Sig

    sig { params(constant: ::Module, block: T.nilable(T.proc.params(scope: Scope).void)).returns(Scope) }
    def create_path(constant, &block)
      constant_name = Tapioca::Runtime::Reflection.name_of(constant)
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

    sig { params(name: String, block: T.nilable(T.proc.params(scope: Scope).void)).returns(Scope) }
    def create_module(name, &block)
      T.cast(create_node(RBI::Module.new(name)), RBI::Scope).tap do |node|
        block&.call(node)
      end
    end

    sig do
      params(
        name: String,
        superclass_name: T.nilable(String),
        block: T.nilable(T.proc.params(scope: RBI::Scope).void),
      ).returns(Scope)
    end
    def create_class(name, superclass_name: nil, &block)
      T.cast(create_node(RBI::Class.new(name, superclass_name: superclass_name)), RBI::Scope).tap do |node|
        block&.call(node)
      end
    end

    sig { params(name: String, value: String).void }
    def create_constant(name, value:)
      create_node(RBI::Const.new(name, value))
    end

    sig { params(name: String).void }
    def create_include(name)
      create_node(RBI::Include.new(name))
    end

    sig { params(name: String).void }
    def create_extend(name)
      create_node(RBI::Extend.new(name))
    end

    sig { params(name: String).void }
    def create_mixes_in_class_methods(name)
      create_node(RBI::MixesInClassMethods.new(name))
    end

    sig do
      params(
        name: String,
        type: String,
        variance: Symbol,
        fixed: T.nilable(String),
        upper: T.nilable(String),
        lower: T.nilable(String),
      ).void
    end
    def create_type_variable(name, type:, variance: :invariant, fixed: nil, upper: nil, lower: nil)
      value = Tapioca::RBIHelper.serialize_type_variable(type, variance, fixed, upper, lower)
      create_node(RBI::TypeMember.new(name, value))
    end

    sig do
      params(
        name: String,
        parameters: T::Array[TypedParam],
        return_type: String,
        class_method: T::Boolean,
        visibility: RBI::Visibility,
        comments: T::Array[RBI::Comment],
      ).void
    end
    def create_method(name, parameters: [], return_type: "T.untyped", class_method: false, visibility: RBI::Public.new,
      comments: [])
      sig_params = parameters.to_h { |param| [param.param.name, param.type] }
      sig = create_sig(parameters: sig_params, return_type: return_type)
      create_method_with_sigs(
        name,
        sigs: [sig],
        parameters: parameters.map(&:param),
        class_method: class_method,
        visibility: visibility,
        comments: comments,
      )
    end

    sig do
      params(
        name: String,
        sigs: T::Array[RBI::Sig],
        parameters: T::Array[RBI::Param],
        class_method: T::Boolean,
        visibility: RBI::Visibility,
        comments: T::Array[RBI::Comment],
      ).void
    end
    def create_method_with_sigs(name, sigs:, parameters: [], class_method: false, visibility: RBI::Public.new,
      comments: [])
      return unless Tapioca::RBIHelper.valid_method_name?(name)

      method = RBI::Method.new(
        name,
        sigs: sigs,
        params: parameters,
        is_singleton: class_method,
        visibility: visibility,
        comments: comments,
      )
      self << method
    end

    sig do
      params(
        parameters: T::Hash[T.any(String, Symbol), String],
        type_parameters: T::Array[String],
        return_type: String,
      ).returns(RBI::Sig)
    end
    def create_sig(parameters:, type_parameters: [], return_type: "T.untyped")
      params = parameters.map do |name, type|
        RBI::SigParam.new(name.to_s, type)
      end
      RBI::Sig.new(type_params: type_parameters, params: params, return_type: return_type)
    end

    private

    sig { returns(T::Hash[String, RBI::Node]) }
    def nodes_cache
      @nodes_cache ||= T.let({}, T.nilable(T::Hash[String, Node]))
    end

    sig { params(node: RBI::Node).returns(RBI::Node) }
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
