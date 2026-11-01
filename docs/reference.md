# Method reference

Generated from the pinned public API contract. Amounts use integer cents; dates use UTC Unix seconds.

| Method | HTTP | Parameters | Result | Success statuses | Idempotency key |
| --- | --- | --- | --- | --- | --- |
| `Accounts.RetrieveFees` | `GET /v1/accounts/fees` | `none` | `TAccountFees` | 200 | No |
| `Accounts.RetrieveNumber` | `GET /v1/accounts/account_number` | `none` | `TAccountNumber` | 200 | No |
| `Accounts.RetrieveCheckoutSettings` | `GET /v1/accounts/checkout_settings` | `none` | `TCheckoutSettings` | 200 | No |
| `Accounts.UpdateCheckoutSettings` | `PATCH /v1/accounts/checkout_settings` | `TUpdateCheckoutSettingsParams` | `TCheckoutSettings` | 200, 202 | Yes |
| `Accounts.CreateCheckoutLogoUpload` | `POST /v1/accounts/checkout_settings/logo_uploads` | `TCreateCheckoutLogoUploadParams` | `TCheckoutAssetUpload` | 201 | Yes |
| `Accounts.CreateCheckoutFaviconUpload` | `POST /v1/accounts/checkout_settings/favicon_uploads` | `TCreateCheckoutFaviconUploadParams` | `TCheckoutAssetUpload` | 201 | Yes |
| `Accounts.DeleteCheckoutAssetUpload` | `DELETE /v1/accounts/checkout_settings/uploads/{id}` | `none` | `TCheckoutAssetUploadDeleted` | 200 | Yes |
| `Accounts.RetrieveContext` | `GET /v1/accounts/context` | `none` | `TAccountContext` | 200 | No |
| `Balances.Retrieve` | `GET /v1/balances` | `none` | `TBalance` | 200 | No |
| `Balances.Forecast` | `GET /v1/balances/forecast` | `TGetBalanceForecastParams` | `TBalanceForecast` | 200 | No |
| `Charges.Create` | `POST /v1/charges` | `TCreateChargeParams` | `TChargeCreated` | 201, 202 | Yes |
| `Charges.List` | `GET /v1/charges` | `TListChargesParams` | `TChargeListResponse` | 200 | No |
| `Charges.Retrieve` | `GET /v1/charges/{id}` | `none` | `TCharge` | 200 | No |
| `Charges.Update` | `PATCH /v1/charges/{id}` | `TUpdateChargeParams` | `TCharge` | 200 | Yes |
| `Charges.Revoke` | `DELETE /v1/charges/{id}` | `none` | `TRevokeChargeResult` | 200, 202 | Yes |
| `Charges.RetrievePayment` | `GET /v1/charges/{id}/payment` | `none` | `TPaymentReceipt` | 200 | No |
| `Charges.RetrieveReceipt` | `GET /v1/charges/{id}/receipt` | `none` | `TFinancialDocument` | 200 | No |
| `Charges.RetrieveBoleto` | `GET /v1/charges/{id}/boleto` | `none` | `TFinancialDocument` | 200 | No |
| `Charges.CreateRefund` | `POST /v1/charges/{id}/refunds` | `TCreateRefundParams` | `TRefund` | 200, 202 | Yes |
| `Charges.ListRefunds` | `GET /v1/charges/{id}/refunds` | `TListChargeRefundsParams` | `TRefundListResponse` | 200 | No |
| `Charges.RetrieveRefundEligibility` | `GET /v1/charges/{id}/refund_eligibility` | `none` | `TRefundEligibility` | 200 | No |
| `Charges.Statistics` | `GET /v1/charges/statistics` | `TGetChargeStatisticsParams` | `TChargeStatistics` | 200 | No |
| `Customers.Create` | `POST /v1/customers` | `TCreateCustomerParams` | `TCustomerCreated` | 200, 201 | Yes |
| `Customers.List` | `GET /v1/customers` | `TListCustomersParams` | `TCustomerListResponse` | 200 | No |
| `Customers.Retrieve` | `GET /v1/customers/{id}` | `none` | `TCustomerListItem` | 200 | No |
| `Customers.Update` | `PATCH /v1/customers/{id}` | `TUpdateCustomerParams` | `TCustomerListItem` | 200 | Yes |
| `Customers.Delete` | `DELETE /v1/customers/{id}` | `none` | `TCustomerDeleted` | 200 | No |
| `Customers.DeleteBatch` | `DELETE /v1/customers` | `TRemoveCustomersParams` | `TCustomerBatchDeleted` | 200 | Yes |
| `Disputes.List` | `GET /v1/disputes` | `TListDisputesParams` | `TDisputeListResponse` | 200 | No |
| `Disputes.Retrieve` | `GET /v1/disputes/{id}` | `none` | `TDispute` | 200 | No |
| `PaymentLinks.Create` | `POST /v1/payment_links` | `TCreatePaymentLinkParams` | `TPaymentLink` | 200, 201 | Yes |
| `PaymentLinks.List` | `GET /v1/payment_links` | `TListPaymentLinksParams` | `TPaymentLinkListResponse` | 200 | No |
| `PaymentLinks.Retrieve` | `GET /v1/payment_links/{id}` | `none` | `TPaymentLinkDetails` | 200 | No |
| `PaymentLinks.Update` | `PATCH /v1/payment_links/{id}` | `TUpdatePaymentLinkParams` | `TPaymentLink` | 200 | Yes |
| `PaymentLinks.SendEmail` | `POST /v1/payment_links/{id}/send_email` | `none` | `TPaymentLinkEmailRequestAccepted` | 202 | Yes |
| `Refunds.List` | `GET /v1/refunds` | `TListRefundsParams` | `TRefundListResponse` | 200 | No |
| `Refunds.Retrieve` | `GET /v1/refunds/{id}` | `none` | `TRefund` | 200 | No |
| `Refunds.RetrieveReceipt` | `GET /v1/refunds/{id}/receipt` | `none` | `TFinancialDocument` | 200 | No |
| `Statements.List` | `GET /v1/statements` | `TListStatementsParams` | `TStatementListResponse` | 200 | No |
| `Statements.Retrieve` | `GET /v1/statements/{id}` | `none` | `TStatement` | 200 | No |
| `WebhookEventTypes.List` | `GET /v1/webhook_event_types` | `none` | `TWebhookEventTypeListResponse` | 200 | No |
| `Webhooks.Create` | `POST /v1/webhooks` | `TCreateWebhookParams` | `TWebhookCreated` | 201 | Yes |
| `Webhooks.List` | `GET /v1/webhooks` | `TListWebhooksParams` | `TWebhookListResponse` | 200 | No |
| `Webhooks.Retrieve` | `GET /v1/webhooks/{webhook_id}` | `none` | `TWebhook` | 200 | No |
| `Webhooks.Update` | `PATCH /v1/webhooks/{webhook_id}` | `TUpdateWebhookParams` | `TWebhook` | 200 | Yes |
| `Webhooks.Delete` | `DELETE /v1/webhooks/{webhook_id}` | `none` | `TRaimsResource` | 204 | Yes |
| `Webhooks.RetrieveHealth` | `GET /v1/webhooks/{webhook_id}/health` | `none` | `TWebhookHealth` | 200 | No |
| `Webhooks.SetPause` | `PATCH /v1/webhooks/{webhook_id}/pause` | `TSetWebhookPauseParams` | `TWebhookPause` | 200 | Yes |
| `Webhooks.RotateSecret` | `POST /v1/webhooks/{webhook_id}/rotate_secret` | `TRotateWebhookSecretParams` | `TWebhookSecretRotation` | 200 | Yes |
| `Webhooks.Test` | `POST /v1/webhooks/{webhook_id}/test` | `none` | `TWebhookTestAccepted` | 202 | Yes |
| `WithdrawalDestinations.List` | `GET /v1/withdrawal_destinations` | `TListWithdrawalDestinationsParams` | `TWithdrawalDestinationListResponse` | 200 | No |
| `WithdrawalDestinations.Retrieve` | `GET /v1/withdrawal_destinations/{id}` | `none` | `TWithdrawalDestination` | 200 | No |
| `Withdrawals.Create` | `POST /v1/withdrawals` | `TCreateWithdrawalParams` | `TWithdrawal` | 200, 202 | Yes |
| `Withdrawals.List` | `GET /v1/withdrawals` | `TListWithdrawalsParams` | `TWithdrawalListResponse` | 200 | No |
| `Withdrawals.Retrieve` | `GET /v1/withdrawals/{id}` | `none` | `TWithdrawal` | 200 | No |
| `Withdrawals.RetrieveLimits` | `GET /v1/withdrawals/limits` | `none` | `TWithdrawalLimits` | 200 | No |
| `Withdrawals.RetrieveSummary` | `GET /v1/withdrawals/summary` | `none` | `TWithdrawalSummary` | 200 | No |
| `Withdrawals.RetrieveAutomaticSettings` | `GET /v1/withdrawals/automatic_settings` | `none` | `TAutomaticWithdrawalSettings` | 200 | No |
| `Withdrawals.UpdateAutomaticSettings` | `PATCH /v1/withdrawals/automatic_settings` | `TUpdateAutomaticWithdrawalSettingsParams` | `TAutomaticWithdrawalSettings` | 200 | Yes |
| `Simulations.Charges.ConfirmPayment` | `POST /v1/simulations/charges/{id}/confirm_payment` | `none` | `TChargeSimulation` | 200 | Yes |
| `Simulations.Charges.FailPayment` | `POST /v1/simulations/charges/{id}/fail_payment` | `none` | `TChargeSimulation` | 200 | Yes |
| `Simulations.Charges.ConfigureScenario` | `POST /v1/simulations/charges/{id}/scenario` | `TChargeScenarioParams` | `TChargeScenario` | 200 | Yes |
| `Simulations.Charges.ResolveScenario` | `POST /v1/simulations/charges/{id}/resolve` | `TResolveChargeScenarioParams` | `TChargeScenario` | 200 | Yes |
| `Simulations.Charges.IssuePayment` | `POST /v1/simulations/charges/{id}/issue_payment` | `TIssueSimulationPaymentParams` | `TCharge` | 200, 202 | Yes |
| `Simulations.Charges.CompensateBoleto` | `POST /v1/simulations/charges/{id}/compensate_boleto` | `none` | `TChargeBoletoCompensation` | 200 | Yes |
| `Simulations.Charges.CreateRefund` | `POST /v1/simulations/charges/{id}/refunds` | `TCreateRefundParams` | `TRefund` | 200, 202 | Yes |
| `Simulations.Refunds.Complete` | `POST /v1/simulations/refunds/{id}/complete` | `none` | `TRefund` | 200 | Yes |
| `Simulations.Refunds.Fail` | `POST /v1/simulations/refunds/{id}/fail` | `none` | `TRefund` | 200 | Yes |

`202` preserves a pending outcome. Simulations require a Sandbox API key. OAuth environment headers are not part of the SDK surface.
