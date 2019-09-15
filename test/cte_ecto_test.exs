defmodule CTE.Ecto.Test do
  use CTE.DataCase

  @moduletag :ecto
  @insert_list [
    [1, 1],
    [1, 2],
    [2, 3],
    [3, 7],
    [1, 4],
    [4, 5],
    [4, 6],
    [6, 8],
    [6, 9]
  ]

  defmodule CH do
    @moduledoc """
    Comments hierarchy
    """
    use CTE,
      otp_app: :cte,
      adapter: CTE.Adapter.Ecto,
      repo: Repo,
      nodes: Comment,
      paths: TreePath
  end

  setup_all do
    start_supervised!({CH, []})

    Repo.delete_all(Comment)
    Repo.delete_all(Author)
    Repo.delete_all(TreePath)

    """
    INSERT INTO "public"."authors" ("id", "name", "inserted_at", "updated_at") VALUES ('1', 'Olie', '2019-07-21 00:47:46', '2019-07-21 00:47:46');
    INSERT INTO "public"."authors" ("id", "name", "inserted_at", "updated_at") VALUES ('2', 'Rolie', '2019-07-21 00:47:46', '2019-07-21 00:47:46');
    INSERT INTO "public"."authors" ("id", "name", "inserted_at", "updated_at") VALUES ('3', 'Polie', '2019-07-21 00:47:46', '2019-07-21 00:47:46');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('1', 'Is Closure Table better than the Nested Sets?', '1', '2019-07-21 01:04:25', '2019-07-21 01:04:25');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('2', 'It depends. Do you need referential integrity?', '2', '2019-07-21 01:05:25', '2019-07-21 01:05:25');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('3', 'Yeah', '1', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('7', 'Closure Table *has* referential integrity?', '2', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('4', 'Querying the data it’s easier.', '3', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('5', 'What about inserting nodes?', '1', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('6', 'Everything is easier, than with the Nested Sets.', '2', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('8', 'I’m sold! And I’ll use its Elixir implementation! <3', '1', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('9', 'w⦿‿⦿t!', '3', '2019-07-21 01:10:35', '2019-07-21 01:10:35');
    INSERT INTO "public"."comments" ("id", "text", "author_id", "inserted_at", "updated_at") VALUES ('281', 'Rolie is right!', '3', '2019-07-21 01:10:35', '2019-07-21 01:10:35');

    """
    |> String.split("\n")
    |> Enum.each(&Repo.query/1)

    for [ancestor, leaf] <- @insert_list do
      """
      INSERT INTO tree_paths (ancestor, descendant, depth)
      SELECT t.ancestor, #{leaf}, t.depth+1
      FROM tree_paths AS t
      WHERE t.descendant = #{ancestor}
      UNION ALL
      SELECT #{leaf}, #{leaf}, 0;
      """
      |> Repo.query()
    end

    :ok
  end

  describe "Forum" do
    test "Get Olie" do
      assert %Author{name: "Olie"} = Repo.get(Author, 1)
    end
  end

  describe "Descendants" do
    test "Retrieve descendants of comment #2, including itself" do
      assert {:ok, [1, 2]} == CH.descendants(1, limit: 2, itself: true)
    end

    test "Retrieve descendants of comment #1, excluding itself" do
      assert {:ok, [2, 3]} == CH.descendants(1, limit: 2)
      assert {:ok, [2, 3, 7, 4, 5, 6, 8, 9]} == CH.descendants(1)
    end

    test "Retrieve all descendants of comment #2, including itself" do
      assert {:ok, [2, 3, 7]} = CH.descendants(2, itself: true)
    end

    test "Retrieve descendants of comment #2, with limit" do
      assert {:ok, [3, 7]} == CH.descendants(2, limit: 3)
    end

    test "Retrieve descendants of comment #2, as comments" do
      assert {:ok,
              [
                %Comment{
                  id: 2,
                  text: "It depends. Do you need referential integrity?",
                  author_id: 2
                }
              ]} = CH.descendants(1, limit: 1, nodes: true)
    end

    test "Retrieve immediate descendants of comment #1, excluding itself" do
      assert {:ok, [2, 3, 7, 4, 5, 6, 8, 9]} == CH.descendants(1)
      assert {:ok, [2, 4]} == CH.descendants(1, depth: 1)
    end
  end

  describe "Ancestors" do
    test "Retrieve ancestors of comment #6, excluding itself" do
      assert {:ok, [1, 4]} == CH.ancestors(6, limit: 2)
    end

    test "Retrieve ancestors of comment #6, including itself" do
      assert {:ok, [1, 4, 6]} == CH.ancestors(6, itself: true)
    end

    test "Retrieve ancestors of comment #6, as comments" do
      assert {:ok,
              [
                %Comment{
                  author_id: 1,
                  text: "Is Closure Table better than the Nested Sets?",
                  id: 1
                },
                %Comment{author_id: 3, text: "Querying the data it’s easier.", id: 4}
              ]} = CH.ancestors(6, nodes: true)
    end

    test "Retrieve ancestors of comment #6 as comments, with limit" do
      assert {:ok,
              [
                %Comment{
                  author_id: 1,
                  text: "Is Closure Table better than the Nested Sets?",
                  id: 1
                }
              ]} = CH.ancestors(6, limit: 1, nodes: true)
    end

    test "Retrieve immediate ancestors of comment #6, including itself" do
      # assert {:ok, [1, 4, 6]} == CH.ancestors(6, itself: true)
      assert {:ok, [4, 6]} == CH.ancestors(6, itself: true, depth: 1)
    end
  end

  describe "Tree paths operations" do
    test "insert descendant of comment #7" do
      assert {:ok, [[1, 281], [2, 281], [3, 281], [7, 281], [281, 281]]} == CH.insert(281, 7)

      assert {:ok, [%Comment{author_id: 3, text: "Rolie is right!", id: 281}]} =
               CH.descendants(7, limit: 1, nodes: true)
    end

    test "delete leaf; comment #9" do
      assert {:ok, [%Comment{text: "w⦿‿⦿t!"}]} =
               CH.descendants(9, limit: 1, itself: true, nodes: true)

      assert :ok == CH.delete(9, limit: 1)

      assert {:ok, []} == CH.descendants(9, limit: 1, itself: true, nodes: true)
      assert {:ok, []} == CH.descendants(9, limit: 1)
    end

    test "delete subtree; comment #6 and its descendants" do
      assert {:ok, [6, 8, 9]} == CH.descendants(6, itself: true)
      assert :ok == CH.delete(6)
      assert {:ok, []} == CH.descendants(6, itself: true)
    end

    test "delete subtree w/o any leafs; comment #5 and its descendants" do
      assert {:ok, [5]} == CH.descendants(5, itself: true)
      assert :ok == CH.delete(5)
      assert {:ok, []} == CH.descendants(5, itself: true)
    end

    test "delete whole tree, from its root; comment #1" do
      assert {:ok, [1, 2, 3, 7, 4, 5, 6, 8, 9]} == CH.descendants(1, itself: true)
      assert :ok == CH.delete(1)
      assert {:ok, []} == CH.descendants(1, itself: true)
    end

    test "move subtree; comment #6, to a child of comment #3" do
      assert {:ok, [1, 4]} == CH.ancestors(6)
      assert :ok = CH.move(6, 3)

      assert {:ok, list} = CH.ancestors(6)
      assert MapSet.subset?(MapSet.new([1, 2, 3]), MapSet.new(list))

      ancestors = MapSet.new([1, 2, 3, 6])
      assert {:ok, list} = CH.ancestors(8)
      assert MapSet.subset?(ancestors, MapSet.new(list))

      assert {:ok, list} = CH.ancestors(9)
      assert MapSet.subset?(ancestors, MapSet.new(list))
    end

    test "return the descendants tree of comment #4" do
      assert {:ok,
              %{
                nodes: %{
                  6 => %Comment{
                    text: "Everything is easier, than with the Nested Sets.",
                    author_id: 2
                  },
                  8 => %Comment{
                    text: "I’m sold! And I’ll use its Elixir implementation! <3",
                    author_id: 1
                  },
                  9 => %Comment{text: "w⦿‿⦿t!", author_id: 3}
                },
                paths: [[6, 6], [6, 8], '\b\b', [6, 9], '\t\t']
              }} = CH.tree(6)
    end
  end
end
