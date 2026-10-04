# Sun time fixtures

`sun-times.csv` holds reference sunrise and sunset times used by the `SunCalculator` unit tests.

- **Source**: NOAA solar equations, sun's upper limb at −0.833° (standard refraction), computed independently of the app with the Python library [astral](https://github.com/sffjunkie/astral) 3.x.
- **Tolerance** in tests: ±60 seconds.
- `none` means the event does not happen that day (polar day or polar night).
- Times are local, with their UTC offset. The Reykjavik row of 21 June shows a sunset that falls after local midnight: it belongs to the evening of 21 June.
- Before release, cross-check a few rows by hand against Apple Weather for the same coordinates.
