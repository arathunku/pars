defmodule Pars do
  require Logger
  @doc ~S"""
  Parses the query and executes handlers for action

  ## Examples

    iex> Pars.parse(%{})
    %{}

    iex> Pars.parse([[":users/list", [%{}, "id", "name", [":user/friends", [%{}, "name"]]]]])
    %{":users/list" => [%{":user/friends" => [%{"name" => "Baz"}], "id" => 1, "name" => "Foo"},
                        %{":user/friends" => [], "id" => 2, "name" => "Bar"},
                        %{":user/friends" => [], "id" => 3, "name" => "Baz"}]}

    iex> Pars.parse([["!users/update", %{"id" => 1, "name" => "FooNew"}]])
    %{"!users/update" => %{"name" => "FooNew", "id" => 1}}

    iex> Pars.parse([[":users/by-id", %{"id" => 1}, "id", "name", [":user/friends", [%{}, "name"]]]])
    %{":users/by-id" => %{"name" => "Foo", "id" => 1, ":user/friends" => [%{"name" => "Baz"}]}}

    iex> Pars.parse([[[":users/by-id", 1], %{"id" => 1}, "id"], [[":users/by-id", 2], %{"id" => 2}, "name"]])
    %{[":users/by-id", 1] => %{"id" => 1}, [":users/by-id", 2] => %{"name" => "Bar"}}
  """

  def parse(query, outer \\ %{}) do
    Logger.debug "#{__MODULE__} parsing: #{inspect query} to: #{inspect outer}"
    Enum.reduce(query, outer, &Pars.handle_resource/2)
  end


  def handle_resource(v, acc) do
    Logger.debug "#{__MODULE__} value: #{inspect v}, acc: #{inspect acc}"
    [ident, params | attrs] = v

    if is_list(ident) do
      [action_name | _ ] = ident
    else
      action_name = ident
    end

    if mut?(action_name) do
      Dict.put(acc, action_name, handle_mut(action_name, params))
    else
      if is_list(params) do
        [ params | attrs ] = params
        returns_list = true
      end
      { raw_attributes, nested_resources } = split_attributes_and_resources(attrs)

      result = Dict.put(
        acc,
        ident,
        handle_inner_resources(
          handle_get(action_name, {params, acc}, raw_attributes),
          nested_resources,
          acc,
          returns_list))

      Logger.debug("result: #{inspect result}")
      result
    end
  end

  def mut?(name) do
    String.first(name) == "!"
  end

  def handle_get(name, params_and_state, raw_attributes) do
    DataSource.get(name, params_and_state, raw_attributes)
  end

  def handle_mut(name, params) do
    DataSource.mut(name, params)
  end

  def split_attributes_and_resources(v) do
    { Enum.filter(v, fn (v) -> !is_list(v) end), Enum.filter(v, &is_list/1) }
  end

  def handle_inner_resources(current_result, resources, acc, returns_list) do
    if Enum.any?(resources) do
      if returns_list do
        result = Enum.map(current_result, fn
          (v) ->
            Pars.parse(resources, v)
        end)
      else
        result = Enum.reduce(resources, current_result, fn
          (v, acc) ->
            Pars.handle_resource(v, acc)
        end)
      end
    else
      current_result
    end
  end
end
