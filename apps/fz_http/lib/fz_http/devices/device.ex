defmodule FzHttp.Devices.Device do
  @moduledoc """
  Manages Device things
  """

  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  import FzHttp.SharedValidators,
    only: [
      validate_fqdn_or_ip: 2,
      validate_omitted: 2,
      validate_list_of_ips: 2,
      validate_no_duplicates: 2,
      validate_list_of_ips_or_cidrs: 2
    ]

  import FzHttp.Queries.INET

  alias FzHttp.Users.User

  schema "devices" do
    field :name, :string
    field :public_key, :string
    field :use_default_allowed_ips, :boolean, read_after_writes: true, default: true
    field :use_default_dns_servers, :boolean, read_after_writes: true, default: true
    field :use_default_endpoint, :boolean, read_after_writes: true, default: true
    field :use_default_persistent_keepalives, :boolean, read_after_writes: true, default: true
    field :endpoint, :string
    field :persistent_keepalives, :integer
    field :allowed_ips, :string
    field :dns_servers, :string
    field :private_key, FzHttp.Encrypted.Binary
    field :server_public_key, :string
    field :remote_ip, EctoNetwork.INET
    field :ipv4, EctoNetwork.INET, read_after_writes: true
    field :ipv6, EctoNetwork.INET, read_after_writes: true
    field :last_seen_at, :utc_datetime_usec
    field :config_token, :string
    field :config_token_expires_at, :utc_datetime_usec

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(device, attrs) do
    device
    |> shared_cast(attrs)
    |> put_next_ipv4()
    |> put_next_ipv6()
    |> shared_changeset()
  end

  def update_changeset(device, attrs) do
    device
    |> shared_cast(attrs)
    |> shared_changeset()
  end

  def field(changeset, field) do
    get_field(changeset, field)
  end

  defp shared_cast(device, attrs) do
    device
    |> cast(attrs, [
      :use_default_allowed_ips,
      :use_default_dns_servers,
      :use_default_endpoint,
      :use_default_persistent_keepalives,
      :allowed_ips,
      :dns_servers,
      :endpoint,
      :persistent_keepalives,
      :remote_ip,
      :ipv4,
      :ipv6,
      :server_public_key,
      :private_key,
      :user_id,
      :name,
      :public_key,
      :config_token,
      :config_token_expires_at
    ])
  end

  defp shared_changeset(changeset) do
    changeset
    |> validate_required([
      :user_id,
      :name,
      :public_key,
      :server_public_key,
      :private_key
    ])
    |> validate_required_unless_default([
      :allowed_ips,
      :dns_servers,
      :endpoint,
      :persistent_keepalives
    ])
    |> validate_omitted_if_default([:allowed_ips, :dns_servers, :endpoint, :persistent_keepalives])
    |> validate_list_of_ips_or_cidrs(:allowed_ips)
    |> validate_list_of_ips(:dns_servers)
    |> validate_no_duplicates(:dns_servers)
    |> validate_fqdn_or_ip(:endpoint)
    |> validate_number(:persistent_keepalives,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 120
    )
    |> validate_ipv4_required()
    |> validate_ipv6_required()
    |> unique_constraint(:ipv4)
    |> unique_constraint(:ipv6)
    |> unique_constraint(:public_key)
    |> unique_constraint(:private_key)
    |> unique_constraint([:user_id, :name])
  end

  defp validate_omitted_if_default(changeset, fields) when is_list(fields) do
    fields_to_validate =
      defaulted_fields(changeset, fields)
      |> Enum.map(fn field ->
        String.trim(Atom.to_string(field), "use_default_") |> String.to_atom()
      end)

    validate_omitted(changeset, fields_to_validate)
  end

  defp validate_required_unless_default(changeset, fields) when is_list(fields) do
    fields_as_atoms = Enum.map(fields, fn field -> String.to_atom("use_default_#{field}") end)
    fields_to_validate = fields_as_atoms -- defaulted_fields(changeset, fields)
    validate_required(changeset, fields_to_validate)
  end

  defp defaulted_fields(changeset, fields) do
    fields
    |> Enum.map(fn field -> String.to_atom("use_default_#{field}") end)
    |> Enum.filter(fn field -> get_field(changeset, field) end)
  end

  defp validate_ipv4_required(changeset) do
    if Application.fetch_env!(:fz_http, :wireguard_ipv4_enabled) do
      validate_required(changeset, :ipv4)
    else
      changeset
    end
  end

  defp validate_ipv6_required(changeset) do
    if Application.fetch_env!(:fz_http, :wireguard_ipv6_enabled) do
      validate_required(changeset, :ipv6)
    else
      changeset
    end
  end

  defp put_next_ipv4(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{ipv4: _ipv4}} -> changeset
      _ -> put_change(changeset, :ipv4, next_available(:ipv4))
    end
  end

  defp put_next_ipv6(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{ipv6: _ipv6}} -> changeset
      _ -> put_change(changeset, :ipv6, next_available(:ipv6))
    end
  end
end
