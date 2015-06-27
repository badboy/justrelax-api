## Base

`/booking/holiday?[parameters]`

## Required Parameters

* `from`: YYYY-MM-DD
* `to`:   YYYY-MM-DD
* `location`: some city name or similar

## Optional parameters

* `roomtype`: One of `[single, double, family]`
    * `family` not implemented yet
* `max_price`: Maximum allowed price in €
* `category`: One of `[shit, best, (empty)]`
* `like`: One of `[shit, best, (empty)]`

## Return values

```json
{
    "results": [{
        "name": "<hotel name>",
        "price": <price in €>,
        "link": <looooooong url>,
        "city": "<city name>",
        "image": "<image url of the hotel>"
    }]
}
```
