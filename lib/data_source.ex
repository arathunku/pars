defmodule DataSource do
  require Logger
  @users %{"users/list" => %{1 => %{"name" => "Foo", "id" => 1, "friends_ids" => [3]},
                             2 => %{"name" => "Bar", "id" => 2, "friends_ids" => []},
                             3 => %{"name" => "Baz", "id" => 3, "friends_ids" => []}}}


  def get(":users/list", {params, acc}=v, attrs) do
    Logger.debug("#{__MODULE__} name: users/list, attrs: #{inspect attrs}")
    @users
    |> Dict.get("users/list")
    |> Dict.values
    |> Enum.map(fn (v) -> Dict.take(v, attrs) end)
  end

  def get(":users/by-id", {params, acc}=v, attrs) do
    Logger.debug("#{__MODULE__}: name: users/by-id, params: #{inspect params}")

    @users
      |> Dict.get("users/list")
      |> Dict.get(Dict.get(params, "id"))
      |> Dict.take(attrs)
  end

  def get(":user/friends", {params, acc}=v, attrs) do
    Logger.debug("#{__MODULE__}: name: users/friends, attrs: #{inspect attrs} v: #{inspect v}")

    ids = DataSource.get(":users/by-id",
                         { Dict.put(params, "id", Dict.get(params, "id", acc["id"])), acc },
                         ["friends_ids"]
    ) |> Dict.get("friends_ids")

    @users
    |> Dict.get("users/list")
    |> Dict.take(ids)
    |> Dict.values
    |> Enum.map(fn (v) -> Dict.take(v, attrs) end)
  end

  def mut("!users/update", params) do
    Logger.debug("#{__MODULE__}: name: users/update, param: #{inspect params}")
    params
  end
end
