defmodule Ecto.Timex.DurationTest do
  use ExUnit.Case
  doctest Ecto.Timex.Duration

  describe "load/1" do
    test "handles empty interval" do
      assert {:ok, d} = Ecto.Timex.Duration.load(%Postgrex.Interval{})
      assert d == Timex.Duration.from_seconds(0)
    end

    test "tracks seconds and microseconds" do
      assert {:ok, d} = Ecto.Timex.Duration.load(%Postgrex.Interval{secs: 123, microsecs: 456})

      assert d ==
               Timex.Duration.add(
                 Timex.Duration.from_seconds(123),
                 Timex.Duration.from_microseconds(456)
               )
    end

    test "rejects non-zero days or months" do
      assert :error = Ecto.Timex.Duration.load(%Postgrex.Interval{days: 1})
      assert :error = Ecto.Timex.Duration.load(%Postgrex.Interval{months: 1})
    end
  end

  describe "dump/1" do
    test "handles microseconds natively" do
      assert {:ok, i} = Timex.Duration.from_microseconds(12345) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{microsecs: 12345}
    end

    test "handles seconds natively" do
      assert {:ok, i} = Timex.Duration.from_seconds(654_321) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{secs: 654_321}
    end

    test "handles mixed seconds and microseconds" do
      assert {:ok, i} =
               Timex.Duration.from_microseconds(123_456_789)
               |> Ecto.Timex.Duration.dump()

      assert i == %Postgrex.Interval{secs: 123, microsecs: 456_789}
    end

    test "handles other units by converting them to seconds" do
      assert {:ok, i} = Timex.Duration.from_seconds(123) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{secs: 123}

      assert {:ok, i} = Timex.Duration.from_minutes(4) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{secs: 240}

      assert {:ok, i} = Timex.Duration.from_hours(2) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{secs: 7200}

      assert {:ok, i} = Timex.Duration.from_days(3) |> Ecto.Timex.Duration.dump()
      assert i == %Postgrex.Interval{secs: 86400 * 3}
    end
  end

  describe "cast/1" do
    test "accept and does not alter durations" do
      duration = Timex.Duration.from_microseconds(123_456_789)
      assert {:ok, ^duration} = Ecto.Timex.Duration.cast(duration)
    end

    test "rejects other values" do
      assert :error = Ecto.Timex.Duration.cast("string")
      assert :error = Ecto.Timex.Duration.cast(123)
      assert :error = Ecto.Timex.Duration.cast(%{months: 1, days: 2, secs: 3})
    end
  end

  describe "to_string/1" do
    test "handles empty interval" do
      assert "PT0S" = %Postgrex.Interval{} |> to_string()
    end

    test "handles interval with only microseconds" do
      assert "PT0.000123S" = %Postgrex.Interval{microsecs: 123} |> to_string()
    end

    test "handles interval with microsecond overflow" do
      assert "PT123.456000S" = %Postgrex.Interval{microsecs: 123_456_000} |> to_string()
      assert "PT168.000789S" = %Postgrex.Interval{secs: 45, microsecs: 123_000_789} |> to_string()
    end

    test "handles interval with multiple units" do
      assert "P1M2DT3.000004S" =
               %Postgrex.Interval{months: 1, days: 2, secs: 3, microsecs: 4}
               |> to_string()
    end
  end
end
