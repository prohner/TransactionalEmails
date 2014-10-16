<custom type="field" name="NotificationType" optional="yes" mustEqual="FRAUD_NOTE">
	<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" style="font-family:arial,helvetica,sans-serif; color:#222222; -webkit-text-size-adjust:100%;" class="deviceWidth">
		<tr>
			<td width="580" align="right" style="padding:12px 0 0 0; font-size:16px; font-weight:bold; mso-line-height-rule:exactly; line-height:20px;" class="deviceWidth">Order Follow-Up</td>
		</tr>
		<tr>
			<td width="580" align="right" style="padding:2px 0 0 0; font-size:12px; mso-line-height-rule:exactly; line-height:16px;" class="deviceWidth">Order #: <custom type="field" name="ORDER_NUM" /></td>
		</tr>
	</table>
	<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" class="deviceWidth">
		<tr>
			<td style="padding:20px 0 17px 0; font-family:arial,helvetica,sans-serif; font-size:13px; color:#222222; mso-line-height-rule:exactly; line-height:17px; -webkit-text-size-adjust:100%;"><b style="font-size:16px; mso-line-height-rule:exactly; line-height:20px;">Hello <custom type="field" name="BILLING_FNAME" />,</b><br /><br />
			
			We need additional information to process your order. Please call our Verifications Department at <span style="font-weight:bold;" class="mobileLink">866-498-7883</span>.</td>
		</tr>
	</table>
</custom>
<custom type="field" name="NotificationType" optional="yes" mustEqual="CC_DECLINED">
	<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" style="font-family:arial,helvetica,sans-serif; color:#222222; -webkit-text-size-adjust:100%;" class="deviceWidth">
		<tr>
			<td width="580" align="right" style="padding:12px 0 0 0; font-size:16px; font-weight:bold; mso-line-height-rule:exactly; line-height:20px;" class="deviceWidth">Order Follow-Up</td>
		</tr>
		<tr>
			<td width="580" align="right" style="padding:2px 0 0 0; font-size:12px; mso-line-height-rule:exactly; line-height:16px;" class="deviceWidth">Order #: <custom type="field" name="ORDER_NUM" /></td>
		</tr>
	</table>
	<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" class="deviceWidth">
		<tr>
			<td style="padding:20px 0 20px 0; font-family:arial,helvetica,sans-serif; font-size:13px; color:#222222; mso-line-height-rule:exactly; line-height:17px; -webkit-text-size-adjust:100%;"><b style="font-size:16px; mso-line-height-rule:exactly; line-height:20px;">Hello <custom type="field" name="BILLING_FNAME" />,</b><br /><br />
			
			Your order has not been processed as we have been unable to obtain credit card authorization. Please call our Verifications Department at <span style="font-weight:bold;" class="mobileLink">866-498-7883</span> to provide an alternate payment method. Have the following information handy when you call:<br /><br />

				<table border="0" cellpadding="0" cellspacing="0" style="font-family:arial,helvetica,sans-serif; font-size:13px; color:#222222; mso-line-height-rule:exactly; line-height:17px; -webkit-text-size-adjust:100%;">
					<tr>
						<td valign="top" style="padding:5px 5px 5px 25px; font-weight:bold;">&#8226;</td>
						<td valign="top" style="padding:5px 15px 5px 0;">Card Holder Name</td>
					</tr>
					<tr>
						<td valign="top" style="padding:5px 5px 5px 25px; font-weight:bold;">&#8226;</td>
						<td valign="top" style="padding:5px 15px 5px 0;">Card Number</td>
					</tr>
					<tr>
						<td valign="top" style="padding:5px 5px 5px 25px; font-weight:bold;">&#8226;</td>
						<td valign="top" style="padding:5px 15px 5px 0;">Expiration Date</td>
					</tr>
					<tr>
						<td valign="top" style="padding:5px 5px 5px 25px; font-weight:bold;">&#8226;</td>
						<td valign="top" style="padding:5px 15px 5px 0;">Billing Address</td>
					</tr>
				</table></td>
		</tr>
	</table>
</custom>