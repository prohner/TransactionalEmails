	<table width="580" border="0" cellpadding="0" cellspacing="0" align="center" class="deviceWidth">
		<tr>
			<td width="120" valign="top" style="mso-table-lspace:0; mso-table-rspace:0; margin:0; padding:8px 0 0 0;"><custom type="image" src="[PRODUCT_IMAGE]" alt="[PRODUCT_NAME]" width="120" border="0" style="display:block; height:auto;" /></td>
			<td width="460" style="mso-table-lspace:0; mso-table-rspace:0; margin:0; padding:8px 0 8px 16px;">
				<table border="0" cellpadding="0" cellspacing="0" width="100%" style="font-family:arial,helvetica,sans-serif; font-size:13px; color:#222222;">
					<tr>
						<td width="100%" style="mso-table-lspace:0; mso-table-rspace:0; margin:0; padding:0 0 0 0; mso-line-height-rule:exactly; line-height:17px;"><custom type="field" name="PRODUCT_NAME" /></td>
					</tr>
					<tr>
						<td width="100%" style="padding:1px 0 0 0; font-size:12px; font-style:italic; mso-line-height-rule:exactly; line-height:16px;">Item #: <span class="mobileLink"><custom type="field" name="PRODUCT_NUM" /></span></td>
					</tr>
					<tr>
						<td width="100%" style="padding:1px 0 0 0; font-size:12px; font-style:italic; mso-line-height-rule:exactly; line-height:16px;">Serial #: <custom type="field" name="SERIAL_NUM" /></td>
					</tr>
					<tr>
						<td width="100%" style="padding:12px 0 3px 0; font-weight:bold; mso-line-height-rule:exactly; line-height:17px;">$<custom type="field" name="UNIT_PRICE" format="currency" /> <custom type="field" name="QUANTITY" optional="yes" minvalue="2">&nbsp;(<custom type="field" name="QUANTITY" format="number" />)</custom></td>
					</tr>
				</table></td>
		</tr>
<custom type="field" name="REVIEWS_NUM" optional="yes" minvalue="1">
		<custom type="field" name="NotificationType" optional="yes" mustEqual="AbandonedCartNotification">
			<tr>
				<td align="center" width="120" style="padding:0 0 5px 0; font-family:arial,helvetica,sans-serif; font-size:11px; line-height:15px; -webkit-text-size-adjust:none;"><custom type="image" src="[STAR_RATING]" alt="" width="70" border="0" style="display:block; height:auto;" /> <custom type="field" name="REVIEWS_NUM" optional="yes" minvalue="1">&nbsp;(<custom type="field" name="REVIEWS_NUM" format="number" />)</custom></td>
				<td width="460" style="padding:1px 0 5px 16px; font-family:arial,helvetica,sans-serif; font-size:12px; font-weight:bold; color:#219531; line-height:16px; -webkit-text-size-adjust:none;"><custom type="field" name="STOCK_STATUS" /></td>
			</tr>
		</custom>		
</custom>		
      	<custom type="field" name="KIT_ITEM_NAME" optional="yes">
         		<tr>
            		<td width="100%" colspan="2" style="padding:2px 5px 10px 10px;">
               		<table width="100%" cellpadding="0" cellspacing="0" border="0" style="font-family:arial,helvetica,sans-serif; font-size:12px; color:#222222; mso-line-height-rule:exactly; line-height:16px;">
                  			<tr>
                     			<td width="100%" colspan="2" style="font-weight:bold;">Includes:</td>
                  			</tr>
                  			<custom type="file" name="product-kit" repeatable="yes" />
               		</table></td>
         		</tr>
      	</custom>
      </table>