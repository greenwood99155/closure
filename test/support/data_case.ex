defmodule CTE.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  @start_apps [
    :ecto,
    :ecto_sql,
    :postgrex
  ]

  using do
    quote do
      alias CTE.{Repo, Author, Comment, TreePath}

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import CTE.DataCase
    end
  end

  setup_all do
    Application.put_env(:ecto, :ecto_repos, [CTE.Repo])

    Application.put_env(:cte, CTE.Repo,
      name: :cte_repo,
      hostname: "localhost",
      username: "postgres",
      password: "postgres",
      database: "ct_ecto_test",
      pool: Ecto.Adapters.SQL.Sandbox
    )

    Enum.each(@start_apps, &Application.ensure_all_started/1)
    {:ok, _pid} = start_supervised(CTE.Repo)

    on_exit(fn ->
      [cte: CTE.Repo, ecto: :ecto_repos]
      |> Enum.each(fn {app, key} -> Application.delete_env(app, key) end)
    end)
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CTE.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(CTE.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
