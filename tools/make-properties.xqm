module namespace props = "http://pekoe.io/properties";
(: use the unparsed-text function ... :)
declare function props:convert-lines($str) {
    for $p in tokenize($str,', ') return <value>{$p}</value>
};

declare function props:convert-string-list($str) {
    for $p in tokenize($str,', ') return <value>{$p}</value>
};
