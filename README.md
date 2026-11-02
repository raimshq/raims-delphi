# Raims Delphi

Official Delphi SDK for the Raims public API.

The SDK is distributed as Delphi source for Windows, Linux, macOS, iOS and
Android. Your application compiles the units for its selected target. It uses
the standard runtime library without third-party Delphi packages or a UI
framework dependency. Native compiler and runtime compatibility have not
been verified. See the
[platform requirements](docs/installation.md#platform-requirements).

## Use the source

Add the SDK's `src` directory to your project's search path and include the
units you use. Keep the units from the same source revision together.
See [installation and updates](docs/installation.md).

## First request

```delphi
uses
  System.SysUtils, Raims.Client, Raims.Params, Raims.Models;

var
  Client: TRaimsClient;
  Params: TListCustomersParams;
  Customers: TCustomerListResponse;
begin
  Client := TRaimsClient.Create(GetEnvironmentVariable('RAIMS_API_KEY'));
  try
    Params := TListCustomersParams.Create;
    try
      Params.SetPageSize(20);
      Customers := Client.Customers.List(Params);
      try
        Writeln(Customers.LastResponse.StatusCode);
        Writeln(Customers.LastResponse.RequestId);
      finally
        Customers.Free;
      end;
    finally
      Params.Free;
    end;
  finally
    Client.Free;
  end;
end;
```

The base URL is `https://api.raims.com` for Sandbox and Production. The key
determines the company, environment and permissions. Keep it on the backend,
outside source code and logs. An API key embedded in a distributed desktop or
mobile application can be extracted; keep authenticated calls in your backend
service.

## Create a charge

The application must define and persist `CustomerId`, `ChargeDueDate` and
`ChargeIdempotencyKey` for the order before making the call. The due date uses
UTC Unix seconds. After losing a response, reuse the key and every parameter,
including the due date.

```delphi
Params := TCreateChargeParams.Create;
try
  Params.SetCustomerId(CustomerId)
    .SetAmountCents(15000)
    .SetDueDate(ChargeDueDate)
    .SetTitle('Order 1234');

  Options := TRaimsRequestOptions.Default;
  Options.IdempotencyKey := ChargeIdempotencyKey;
  Charge := Client.Charges.Create(Params, Options);
  try
    HttpStatus := Charge.LastResponse.StatusCode;
    RequestId := Charge.LastResponse.RequestId;
  finally
    Charge.Free;
  end;
finally
  Params.Free;
end;
```

This example uses `TCreateChargeParams` from `Raims.Params`, `TChargeCreated`
from `Raims.Models` and `TRaimsRequestOptions` from `Raims.Core`. `15000`
represents R$150.00. The SDK does not generate idempotency keys or retry writes
automatically. HTTP `202` indicates a pending result; query the resource to
determine the financial outcome.

## Resources

`Accounts`, `Balances`, `Customers`, `Charges`, `PaymentLinks`, `Refunds`,
`Disputes`, `Statements`, `Withdrawals`, `WithdrawalDestinations`, `Webhooks`,
`WebhookEventTypes`, `Simulations.Charges` and `Simulations.Refunds`.

Services provide methods such as `Create`, `Retrieve`, `Update` and `List`,
depending on the resource. Simulations require a Sandbox key. The SDK does not
offer environment selection or OAuth.

## Ownership and pagination

The caller frees parameters and returned resources. The client owns its service
objects. Typed nested objects and typed object-array items are independent
copies that the caller also frees. See [ownership](docs/usage.md#ownership)
before accessing nested data.

Cursor pages support `NextPage`, `PreviousPage` and `AutoPagingEach`. Navigation
preserves the original filters and request options. Keep the client open while
fetching pages. See [pagination](docs/usage.md#pagination).

## Documentation

- [Installation and updates](docs/installation.md)
- [Configuration, types, ownership and files](docs/usage.md)
- [Errors, idempotency and retries](docs/errors-and-retries.md)
- [Receiving webhooks](docs/webhooks.md)
- [Method reference](docs/reference.md)
- [Contributing](CONTRIBUTING.md) and [security](SECURITY.md)
- [API documentation](https://docs.raims.com/en/api)

Distributed under the [MIT license](LICENSE).
