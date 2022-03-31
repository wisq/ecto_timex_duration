# Ecto.Timex.Duration

Store `Timex.Duration` objects in Postgres as the `interval` type.

## Installation

I'll look at adding this to Hex once I've tested it in my own project.  In the mean time, you can use this directly from GitHub:

```elixir
def deps do
  [
    {:ecto_timex_duration, git: "https://github.com/wisq/ecto_timex_duration.git"}
  ]
end
```

## Usage

In your Ecto migrations, create your fields with type `interval`:

```elixir
  add(:renewal_period, :interval)
```

Then in your Ecto schema, use `Ecto.Timex.Duration` as a field type:

```elixir
  field :renewal_period, Ecto.Timex.Duration, default: Timex.Duration.from_seconds(0)
```

## Limitations

Postgres and `Timex.Duration` have a different idea how days, months, and years work — basically any unit larger than hours.

Specifically, `Timex.Duration.from_days(1)` is the same as `Timex.Duration.from_hours(24)` or `Timex.Duration.from_seconds(86400)` — all three are stored as 86400 seconds, even though this is not always the case when daylight savings is concerned.

`Timex.Duration` also has no real concept of months or years — there are no `from_month` or `from_year` functions.  Since it only stores durations as seconds, there's no safe way to handle these concepts — every month (and every fourth year) has a different number of seconds than the last.

Conversely, Postgres keeps all these units separated.  If you add an interval of `1 day` or `1 month` or `1 year` to a `date` or `timestamp`, it will just increment the corresponding field.  Furthermore, it has no automatic conversion between months, days, and time units — an interval of `1 month 50 days 240 hours` is perfectly acceptable (and is NOT the same as `80 days 240 hours` or `1 month 60 days`).

This leads to some major discrepancies in how the two handle date arithmetic:

| Start date             | Interval  | Timex                | Postgres             | Match    |
| ----------             | --------  | -----                | --------             | -----    |
| 2022-03-01 06:00 EST   | 15 days   | 2022-03-16 07:00 EDT | 2022-03-16 06:00 EDT | &#10060; |
| 2022-03-01 06:00 EST   | 360 hours | 2022-03-16 07:00 EDT | 2022-03-16 07:00 EDT | &#9989;  |
| 2022-02-01             | 1 month¹  | 2022-03-03           | 2022-03-01           | &#10060; |
| 2022-02-01             | 30 days   | 2022-03-03           | 2022-03-03           | &#9989;  |
| 2024-01-01 (leap year) | 1 year²   | 2024-12-31           | 2025-01-01           | &#10060; |
| 2022-01-01             | 1 year²   | 2023-01-01           | 2023-01-01           | &#9989;  |

¹ simulated using `Timex.Duration.from_days(30)`<br/>
² simulated using `Timex.Duration.from_days(365)` (and identical to `12 months` in Postgres)

This means that **there is no safe way to represent Postgres "day" or "month" intervals as `Timex.Duration` objects**, since these are fundamentally different concepts in each environment.  Accordingly, if this library is asked to handle a Postgres interval with a non-zero `month` or `day` figure, it will raise an error instead.

Does this mean you can't store large `Timex.Duration` objects with this library?  **No!**  As per above, Postgres can handle time values much larger than a single day.  If you take a `Timex.Duration.from_days(1)` structure and store it using this library, you'll end up with an interval of `24 hours`.  A `from_days(30)` structure (to *very crudely* simulate a month) would be stored as `720 hours`.

As long as you're okay with this limitation, this library should work fine for you.  Everything will effectively use (micro)seconds as a base unit, your `Timex.Duration` math will exactly match your Postgres SQL math, and nothing unexpected will happen.  (Just make sure nobody sneaks actual days or months into the database.)

If you actually want **correct** day and month arithmetic, you'll have to store them separately and use `Timex.shift/2` to adjust those date fields directly.  (Consider using [ecto_interval][1] instead.)

## Acknowledgements

Thanks to [ecto_interval][1] for providing the inspiration and base example code for this.

[1]: https://github.com/OvermindDL1/ecto_interval
