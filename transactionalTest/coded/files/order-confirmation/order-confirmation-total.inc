<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" style="font-family:arial,helvetica,sans-serif; font-size:13px; color:#222222; mso-line-height-rule:exactly; line-height:17px; -webkit-text-size-adjust:100%;" class="deviceWidth">
		<tr>
			<td width="100%" colspan="2" height="8" style="font-size:8px; line-height:1px;" class="deviceWidth">&nbsp;</td>
		</tr>
		<tr>
			<td width="100%" colspan="2" style="padding:0 0 0 0; border-bottom:4px double #dfdfdf;" class="deviceWidth">&nbsp;</td>
		</tr>
		<tr>
			<td width="465" align="right" style="padding:15px 0 0 0; font-weight:bold;">Order Subtotal:</td>
			<td width="115" align="right" style="padding:15px 0 0 0; font-weight:bold;">$<custom type="field" name="SUBTOTAL" format="currency" /></td>
		</tr>
		<tr>
			<td width="465" align="right" style="padding:1px 0 0 0;">Shipping &amp; Handling:</td>
			<td width="115" align="right" style="padding:1px 0 0 0;">$<custom type="field" name="SHIPPING_HANDLING" format="currency" /></td>
		</tr>
		<tr>
			<td width="465" align="right" style="padding:1px 0 0 0;">Sales Tax:</td>
			<td width="115" align="right" style="padding:1px 0 0 0;">$<custom type="field" name="TAX" format="currency" /></td>
		</tr>
		<custom type="field" name="MISC_CHARGES" optional="yes">
			<tr>
				<td width="465" align="right" style="padding:1px 0 0 0;">Misc. Charges:</td>
				<td width="115" align="right" style="padding:1px 0 0 0;">$<custom type="field" name="MISC_CHARGES" format="currency" /></td>
			</tr>
		</custom>
		<custom type="field" name="DISCOUNTS" optional="yes">
			<tr>
				<td width="465" align="right" style="padding:1px 0 0 0;">Discounts:</td>
				<td width="115" align="right" style="padding:1px 0 0 0; color:#cc0000;">($<custom type="field" name="DISCOUNTS" format="currency" />)</td>
			</tr>
		</custom>
		<tr>
			<td width="465" align="right" style="padding:10px 0 0 0; font-size:16px; font-weight:bold; mso-line-height-rule:exactly; line-height:20px;">Order Total:</td>
			<td width="115" align="right" style="padding:10px 0 0 0; font-size:16px; font-weight:bold; mso-line-height-rule:exactly; line-height:20px;">$<custom type="field" name="TOTAL" format="currency" /></td>
		</tr>
		<custom type="file" name="order-confirmation-payment" repeatable="yes" />
	</table>