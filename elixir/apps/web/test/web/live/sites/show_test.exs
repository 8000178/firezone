defmodule Web.Live.Sites.ShowTest do
  use Web.ConnCase, async: true

  setup do
    account = Fixtures.Accounts.create_account()
    actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
    identity = Fixtures.Auth.create_identity(account: account, actor: actor)
    subject = Fixtures.Auth.create_subject(account: account, actor: actor, identity: identity)

    group = Fixtures.Gateways.create_group(account: account, subject: subject)
    gateway = Fixtures.Gateways.create_gateway(account: account, group: group)
    gateway = Repo.preload(gateway, :group)

    %{
      account: account,
      actor: actor,
      identity: identity,
      subject: subject,
      group: group,
      gateway: gateway
    }
  end

  test "redirects to sign in page for unauthorized user", %{
    account: account,
    group: group,
    conn: conn
  } do
    assert live(conn, ~p"/#{account}/sites/#{group}") ==
             {:error,
              {:redirect,
               %{
                 to: ~p"/#{account}",
                 flash: %{"error" => "You must log in to access this page."}
               }}}
  end

  test "renders deleted gateway group without action buttons", %{
    account: account,
    group: group,
    identity: identity,
    conn: conn
  } do
    group = Fixtures.Gateways.delete_group(group)

    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    assert html =~ "(deleted)"
    refute html =~ "Danger Zone"
    refute html =~ "Add"
    refute html =~ "Delete"
    refute html =~ "Edit"
    refute html =~ "Deploy"
  end

  test "renders breadcrumbs item", %{
    account: account,
    group: group,
    identity: identity,
    conn: conn
  } do
    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Sites"
    assert breadcrumbs =~ group.name
  end

  test "allows editing gateway groups", %{
    account: account,
    group: group,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    assert lv
           |> element("a", "Edit Site")
           |> render_click() ==
             {:error, {:live_redirect, %{to: ~p"/#{account}/sites/#{group}/edit", kind: :push}}}
  end

  test "renders group details", %{
    account: account,
    actor: actor,
    identity: identity,
    group: group,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    table =
      lv
      |> element("#group")
      |> render()
      |> vertical_table_to_map()

    assert table["name"] =~ group.name
    assert table["created"] =~ actor.name
  end

  test "renders online gateways table", %{
    account: account,
    actor: actor,
    identity: identity,
    group: group,
    gateway: gateway,
    conn: conn
  } do
    :ok = Domain.Gateways.connect_gateway(gateway)
    Fixtures.Gateways.create_gateway(account: account, group: group)

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    rows =
      lv
      |> element("#gateways")
      |> render()
      |> table_to_map()

    assert length(rows) == 1

    rows
    |> with_table_row("instance", gateway.name, fn row ->
      assert row["token created at"] =~ actor.name
      assert row["status"] =~ "Online"
    end)
  end

  test "renders gateway status", %{
    account: account,
    group: group,
    gateway: gateway,
    identity: identity,
    conn: conn
  } do
    :ok = Domain.Gateways.connect_gateway(gateway)

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    lv
    |> element("#gateways")
    |> render()
    |> table_to_map()
    |> with_table_row("instance", gateway.name, fn row ->
      assert gateway.last_seen_remote_ip
      assert row["remote ip"] =~ to_string(gateway.last_seen_remote_ip)
      assert row["status"] =~ "Online"
      assert row["token created at"]
    end)
  end

  test "renders resources table", %{
    account: account,
    identity: identity,
    group: group,
    conn: conn
  } do
    resource =
      Fixtures.Resources.create_resource(
        account: account,
        connections: [%{gateway_group_id: group.id}]
      )

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    resource_rows =
      lv
      |> element("#resources")
      |> render()
      |> table_to_map()

    Enum.each(resource_rows, fn row ->
      assert row["name"] =~ resource.name
      assert row["address"] =~ resource.address
      assert row["sites"] =~ group.name
      assert row["authorized groups"] == "None, create a Policy to grant access."
    end)
  end

  test "renders authorized groups peek", %{
    account: account,
    identity: identity,
    group: group,
    conn: conn
  } do
    resource =
      Fixtures.Resources.create_resource(
        account: account,
        connections: [%{gateway_group_id: group.id}]
      )

    policies =
      [
        Fixtures.Policies.create_policy(
          account: account,
          resource: resource
        ),
        Fixtures.Policies.create_policy(
          account: account,
          resource: resource
        ),
        Fixtures.Policies.create_policy(
          account: account,
          resource: resource
        )
      ]
      |> Repo.preload(:actor_group)

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    resource_rows =
      lv
      |> element("#resources")
      |> render()
      |> table_to_map()

    Enum.each(resource_rows, fn row ->
      for policy <- policies do
        assert row["authorized groups"] =~ policy.actor_group.name
      end
    end)

    Fixtures.Policies.create_policy(
      account: account,
      resource: resource
    )

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    resource_rows =
      lv
      |> element("#resources")
      |> render()
      |> table_to_map()

    Enum.each(resource_rows, fn row ->
      assert row["authorized groups"] =~ "and 1 more"
    end)
  end

  test "allows deleting gateway groups", %{
    account: account,
    group: group,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/sites/#{group}")

    lv
    |> element("button", "Delete")
    |> render_click()

    assert_redirected(lv, ~p"/#{account}/sites")

    assert Repo.get(Domain.Gateways.Group, group.id).deleted_at
  end
end
