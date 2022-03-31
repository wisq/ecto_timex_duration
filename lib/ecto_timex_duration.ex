if Code.ensure_loaded?(Postgrex) do
  defmodule Ecto.Timex.Duration do
    @moduledoc """
    This uses the Postgrex.Interval type to store Timex.Duration values.
    """
    if macro_exported?(Ecto.Type, :__using__, 1) do
      use Ecto.Type
    else
      @behaviour Ecto.Type
    end

    @impl true
    def type, do: Postgrex.Interval

    @impl true
    def cast(%Timex.Duration{} = duration), do: {:ok, duration}
    def cast(_), do: :error

    @impl true
    def load(%Postgrex.Interval{} = interval) do
      try do
        {:ok,
         interval
         |> Map.from_struct()
         |> Enum.map(fn {unit, count} -> to_microseconds(unit, count) end)
         |> Enum.sum()
         |> Timex.Duration.from_microseconds()}
      catch
        :unsupported ->
          raise(
            ArgumentError,
            "Cannot convert #{inspect(interval)} into Timex.Duration: " <>
              "non-zero months/days are not supported"
          )
      end
    end

    defp to_microseconds(:microsecs, usecs), do: usecs
    defp to_microseconds(:secs, secs), do: secs * 1_000_000
    defp to_microseconds(:days, 0), do: 0
    defp to_microseconds(:months, 0), do: 0

    defp to_microseconds(:days, _), do: throw(:unsupported)
    defp to_microseconds(:months, _), do: throw(:unsupported)

    @impl true
    def dump(%Timex.Duration{} = duration) do
      usecs = Timex.Duration.to_microseconds(duration)

      {:ok,
       %Postgrex.Interval{
         secs: div(usecs, 1_000_000),
         microsecs: rem(usecs, 1_000_000)
       }}
    end
  end

  defimpl String.Chars, for: [Postgrex.Interval] do
    import Kernel, except: [to_string: 1]

    def to_string(interval) do
      interval
      |> handle_microsecs_overflow()
      |> Map.from_struct()
      |> Map.reject(fn {_, count} -> count == 0 end)
      |> then(fn
        map when map == %{} -> %{secs: 0}
        %{microsecs: _} = map -> Map.put_new(map, :secs, 0)
        map -> map
      end)
      |> Enum.sort_by(fn {unit, _} -> sort_order(unit) end)
      |> Enum.map(fn {unit, count} -> to_string(unit, count) end)
      |> Enum.join("")
      |> then(fn iso -> "P#{iso}S" end)
    end

    # Trying to avoid floating point math here.
    defp handle_microsecs_overflow(%{secs: secs, microsecs: usecs} = map) when usecs > 999_999 do
      map
      |> Map.put(:secs, secs + div(usecs, 1_000_000))
      |> Map.put(:microsecs, rem(usecs, 1_000_000))
    end

    defp handle_microsecs_overflow(%{secs: _, microsecs: _} = map), do: map

    defp sort_order(:months), do: 1
    defp sort_order(:days), do: 2
    defp sort_order(:secs), do: 3
    defp sort_order(:microsecs), do: 4

    defp to_string(:months, n), do: "#{n}M"
    defp to_string(:days, n), do: "#{n}D"
    defp to_string(:secs, n), do: "T#{n}"
    defp to_string(:microsecs, n), do: "." <> String.pad_leading("#{n}", 6, "0")
  end

  defimpl Inspect, for: [Postgrex.Interval] do
    def inspect(inv, _opts) do
      inspect(Map.from_struct(inv))
    end
  end

  if Code.ensure_loaded?(Phoenix.HTML.Safe) do
    defimpl Phoenix.HTML.Safe, for: [Postgrex.Interval] do
      def to_iodata(inv) do
        to_string(inv)
      end
    end
  end
end
