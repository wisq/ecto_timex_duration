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

**This library cannot handle Postgres intervals that contain a non-zero number of days, weeks, months, or years.**

If you attempt to store `Timex.Duration.from_days(10)`, it will be stored as `240 hours` in interval format, and can be read back just fine.

However, if your database contains an interval of `10 days` and you try to read it with this library, you'll get an error.  This is by design, since **there is no safe & correct way to handle units larger than hours** in a `Timex.Duration` — yes, despite it having a `from_days` function.

As long as you're okay with this limitation, this library should work fine for you.  Everything will effectively use (micro)seconds as a base unit, your `Timex.Duration` math will exactly match your Postgres SQL math, and nothing unexpected will happen.  (Just make sure nobody sneaks actual days or months into the database.)

### The gorey details

Postgres and `Timex.Duration` have a different idea how days, months, and years work — basically any unit larger than hours.

Postgres intervals track months, days, and time separately:

```sql
# select '2020-03-01 00:00 EST'::timestamp with time zone + '15 days'::interval;
2020-03-16 00:00:00-04

# select '2020-03-01 00:00 EST'::timestamp with time zone + '1 month'::interval;
2020-04-01 00:00:00-04

# select '2020-03-01 00:00 EST'::timestamp with time zone + '1 year'::interval;
2021-03-01 00:00:00-05
```

Conversely, `Timex.Duration.from_days(1)` is the same as `Timex.Duration.from_hours(24)` or `Timex.Duration.from_seconds(86400)` — all three are stored as 86400 seconds, even though this is not always the case when daylight savings is concerned:

```elixir
iex(1)> ~D[2022-03-01] |> Timex.to_datetime("America/Toronto") |> Timex.add(Timex.Duration.from_days(15))
#DateTime<2022-03-16 01:00:00-04:00 EDT America/Toronto>
```

Note that the time has changed by one hour, due to daylight savings.  That's because what Timex is **really** doing is more akin to this:

```sql
# select '2020-03-01 00:00 EST'::timestamp with time zone + '360 hours'::interval;
2020-03-16 01:00:00-04
```

To emulate how Postgres treats `15 days`, you would need to use `Timex.shift/2` instead:

```elixir
iex(2)> ~D[2022-03-01] |> Timex.to_datetime("America/Toronto") |> Timex.shift(days: 15)
#DateTime<2022-03-16 00:00:00-04:00 EDT America/Toronto>
```

`Timex.Duration` also has no real concept of months or years — there are no `from_month` or `from_year` functions.  Since it only stores durations as seconds, there's no sane way to handle these concepts — every month (and every fourth year) has a different number of seconds than the last.

(Yes, if you `inspect` a `Timex.Duration` structure, you'll find that it *pretends* to understand days and months — e.g. `Timex.Duration.from_days(45) |> inspect` results in `#<Duration(P1M15D)>`, suggesting a once-month fifteen-day interval in ISO 8601 format.  However, this is **incorrect** — it would be much more correctly represented as `PT1080H`, a 1080-hour interval.)

Does this mean you can't store large `Timex.Duration` objects with this library?  **No!**  As per above, Postgres can handle time values much larger than a single day.  If you take a `Timex.Duration.from_days(1)` structure and store it using this library, you'll end up with an interval of `24 hours`.  A `from_days(30)` structure (to *very crudely* simulate a month) would be stored as `720 hours`.

If you actually want **correct** day and month arithmetic, you'll have to store them separately and use `Timex.shift/2` to adjust those date fields directly.  (Consider using [ecto_interval][1] instead.)

(Of course, I **could** create some sort of `ExtendedDuration` module that wraps integer months, integer days, and a `Timex.Duration` for the time component.  But that would introduce a whole bunch of complexity and additional functions — and it wouldn't be compatible with other `Timex` functions — so it sorta defeats the purpose of this library, which is to store intervals as a simple & familiar datatype.)

## Acknowledgements

Thanks to [ecto_interval][1] for providing the inspiration and base example code for this.

[1]: https://github.com/OvermindDL1/ecto_interval
