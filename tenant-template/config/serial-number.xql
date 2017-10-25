xquery version "3.0";
import module namespace sn="http://gspring.com.au/pekoe/serial-numbers"  at "xmldb:exist:///db/apps/pekoe/modules/serial-numbers.xqm";

declare variable  $local:for := request:get-parameter('for','');
declare variable $local:value := request:get-parameter("value",());
(: Requires a config map  'item-id-name' : 'receipt_number' and 'id-number-picture' : 'AA000000' :)

declare variable $local:config := map {
    'receipt' : map {'item-id-name':'receipt', 'id-number-picture': '000000','id-prefix':'P4'},
    'trust-payment' : map {'item-id-name':'trust-payment-number', 'id-number-picture': '000000'},
    'myob-number' : map {'item-id-name':'myob-number', 'id-number-picture': '0','id-prefix' : '4-'}  
};

(: Consider the possibility of writing the created number, and job file, and user into a log. :)
if (request:get-method() eq 'POST') then sn:recycle-padded-id($local:config($local:for), $local:value)
else <result>{sn:get-next-padded-id($local:config($local:for))}</result>