xquery version "3.0";
import module namespace tenant = "http://pekoe.io/tenant"                at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
declare %private variable $local:aws_user := environment-variable('AWS_USER');
declare %private variable $local:aws_pass := environment-variable('AWS_PASS');

(: The solution to the nodeproxy problem is to use util:deep-copy. Not sure if that solves teh other issues. 
:)

declare variable $local:test-mail := <mail created-dateTime="2015-02-24T18:52:53.709+10:30" created-by="admin">
    <from>alisterhp@mac.com</from>
    <to>
        gspringtech@gmail.com
    </to>
    <cc/>
    <subject>Assembly Day booking for 2015-02-21
    </subject>
    <message>
        <text>This is basic test. Where is the real thing?</text>
        <xhtml>
            <html>
                <p xmlns="http://www.w3.org/1999/xhtml">Dear Alister</p>
            </html>
        </xhtml>
    </message>
</mail>
;


declare function local:copy-nodes($nodes as node()*) as item()* {
    for $node in $nodes/node() return local:dispatch($node)
};

(:  Get the filename. 
 : Check to see if it's a valid document. 
 : Get its mimetype.
 : Convert it to binary and return the attachment.
 :)
declare function local:attachment($node) {
    let $path :=  $node/normalize-space(text())
    return 
        if (util:binary-doc-available($path)) then (
            let $filename := tokenize($path,'/')[last()]
            let $mimetype := xmldb:get-mime-type($path)
            return
            <attachment filename='{$filename}' mimetype='{$mimetype}'>{util:binary-doc($path)}</attachment>
        ) else ()
   
};


declare function local:clean-value($node) {
(: Note - if this returns an empty sequence, it causes an error. :)
    if (empty($node) or $node eq '') then ''
    else element {name($node)} {$node/normalize-space(text())}
};

declare function local:to($node) {
    if (empty($node) or $node eq '') then <to>dba@pekoe.io</to> (: effectively reports an error :)
    else if (contains($node,',')) then 
        for $to in tokenize($node, ',')
        return <to>{normalize-space($to)}</to>
    else <to>{$node/normalize-space(text())}</to>
};

declare function local:cc($node) {
    if (contains($node,',')) then 
        for $to in tokenize($node, ',')
        return <cc>{normalize-space($to)}</cc>
    else <cc>{$node/normalize-space(text())}</cc>
};

(: IIRC this helps overcome the ProxyNode issue when a mail message is stored in a file. :)
 declare function local:dispatch($node as node()) as item()* {
    typeswitch($node)
        case text() return 
            if (normalize-space($node) eq '') then (
                (:util:log('debug', 'DELETING WHITESPACE FROM ' || $node/../name(.) ):)
                ) else $node
        case comment() return $node
        case attribute() return $node
        case element(attachment) return local:attachment($node)
        case element(to) return local:to($node)
        case element(from) return local:clean-value($node)
        case element(cc) return  local:cc($node)
        case element(subject) return local:clean-value($node)
(:        case element(xhtml) return <xhtml>{util:string-to-binary(util:serialize($node/*, 'method=xml'))}</xhtml>:)
        case $node as element()
         return
            element {name($node)}
                    {    for $c in $node/(* | text() | @*) (: NOTE The omission of @* here cost me about 3 hours grief. :)
                         return local:dispatch($c) } 
        default return local:copy-nodes($node)
};


(:
   
   NOTE: to DEBUG email:
   First, turn on debugging below...
   Then, tail -f /usr/local/exist/tools/wrapper/logs/wrapper.log
   
   The latest error occurred after moving the server - with a hostname change. 
   501 Syntactically invalid HELO argument(s)
   Solved by adding mail.smtp.localhost below...
   
   ERROR (LogFunction.java [eval]:146) - (Line: 158 /db/apps/pekoe/mailer.xql) java:java.lang.NullPointerException: Unexpected error from JavaMail layer (Is your message well structured?): null
   missing message text. Put something into the message/text
   
:)
declare function local:send-email($message) {
let $props := <properties>
                <property name="mail.debug" value="false" />
                <property name="mail.smtp.localhost" value="ded1101" />
                <property name="mail.smtp.ssl.enable" value="true"/>
                <property name="mail.smtp.starttls.enable" value="true" />
                <property name="mail.smtp.auth" value="true"/>
                <property name="mail.smtp.port" value="465"/>
                <property name="mail.smtp.host" value="email-smtp.us-west-2.amazonaws.com"/>
                <property name="mail.smtp.user" value="{$local:aws_user}"/>
                <property name="mail.smtp.password"  value="{$local:aws_pass}"/>
        </properties>
        
    let $session := mail:get-mail-session($props)
    (:let $message := util:deep-copy(doc($job)/mail)  KEEP THIS - It's useful to remember. :)
    let $m := local:dispatch($message)
(:    let $save-prepared := xmldb:store('/db/temp','prepared-mail.xml',$m   ):)
    let $log := util:log-app('info','login.pekoe.io', '%%%%%%%%% ABOUT TO SEND MAIL FROM ' || $message/from || ' TO ' || $message/to || ' %%%%%%%%%%%%%% ')
    let $send :=  try { mail:send-email(xs:long($session), $m) } catch * { util:log("error", concat($err:code, ": ", $err:description)), <result status='error'>{$err:description}</result>    }
    
    
    return $send
  

};

(: This is called by the tenant's site-tools module :)

let $job-bundle := request:get-attribute('job-bundle')  (: SET IN THE CONTROLLER - but this is the PATH, not the data file.:)
let $mail-map := request:get-attribute("mail-map") (: SHOULD contain keys mail and job. The job IS THE DOCUMENT, so document-uri WORKS. :)
let $mail := $mail-map?mail
let $sent :=  local:send-email($mail)

(: The remainder of the query is about keeping a record of the sent mail :)
let $job := $mail-map?job
let $template := substring-after($mail-map?template,"templates/")
let $current-date := adjust-date-to-timezone(current-date(),())
let $current-user := sm:id()//sm:real
let $current-username := $current-user/sm:username/text()
return if (empty($sent)) 
        then 
            ( 
               if (($job//email)[last()]/sent-date eq '') then (: The User created this Email with an attachment. :)
                    let $email := <email created-by='{$current-username}' created-dateTime='{current-dateTime()}'>
                        <from>{normalize-space($mail-map?mail/from)}</from>
                        <to>{string-join(normalize-space($mail-map?mail/to),',')}</to>
                        <sent-date>{$current-date}</sent-date>
                        <template-used>{$template}</template-used>
                        {$job//email[last()]/attachment}
                    </email>
                    return (update replace ($job//email)[last()] with $email, <result status='success'>Refresh</result>)
               else (: The system is recording that an email was sent. :)
                    let $email := <email created-by='{$current-username}' created-dateTime='{current-dateTime()}'>
                        <from>{normalize-space($mail-map?mail/from)}</from>
                        <to>{string-join(normalize-space($mail-map?mail/to),',')}</to>
                        <sent-date>{$current-date}</sent-date>
                        <template-used>{$template}</template-used>
                        </email>
                    return (update insert $email into $job/*, <result status='success'>Refresh</result>)
          
            )
            else <result status='error'>{$sent}</result>
