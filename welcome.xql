xquery version "3.0" encoding "UTF-8";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
(: Need to make RESTXQ-specific modules - distinct from REST. :)
(:import module namespace tenant = "http://pekoe.io/tenant" at "modules/tenant.xqm";:)

declare variable $local:tenant := replace(req:cookie('tenant'),'%22','');
declare variable $local:tenant-path := '/db/pekoe/tenants/' || $local:tenant;
declare variable $local:tenant-info := doc($local:tenant-path || '/config/tenant.xml')/tenant;


declare  
%rest:GET
%rest:path("/pekoe/welcome")
%output:media-type("text/html")
%output:method("html5")

function local:welcome() {
<html><head>

<link rel='stylesheet' href='/pekoe-common/dist/css/bootstrap.css' />
<style type='text/css'>/* <![CDATA[ */
html, body {margin:0; padding:5px;}
/* ]]> */
</style>
<meta charset="UTF-8"/>
<title>Welcome to Pekoe</title>
</head>
<body>
<div style='width:900px'>
    <h1>Pekoe Job Manager for {$local:tenant-info/string(name)}</h1> 
    <h2>Overview</h2>
    <p>The Pekoe Job Manager consists of this work area and your bookmarks.</p>
    <h2>Bookmarks</h2>
    <div><p>The bookmarks area is your starting point. The first item in the list will automatically open when you start Pekoe
    (eg. this Welcome).</p>
    <p>You can have multiple folders (<span >Favourites</span>, Reports etc) - normally only one will be open at a time. The first folder will always be open when you start Pekoe.</p>
    <p>You can make changes by clicking the <span><i class="glyphicon glyphicon-edit"></i> (Edit)</span> button. Once in Edit mode, you can either 
    <span >Save <i class='glyphicon glyphicon-floppy-disk'></i></span> or <span >Revert <i class='glyphicon glyphicon-refresh'></i></span> .</p>
    <p>In Edit mode: 
    <ul>
        <li><b>Create a folder</b> by typing a name into the <span>New Bookmarks folder</span> box and pressing Return. The "placeholder" will disappear when you add a bookmark.</li>
        <li><b>Reorder</b> an item by dragging and dropping to where you want it. If you open up another Folder, you can drag it there.</li>
        <li><b>Reorder the folders</b> by dragging them. (Easier when they are closed.)</li>
        <li><b>Add a Bookmark</b> by: 
            <ul><li>dragging a Tab into the Bookmarks list, or</li>
            <li>use the <span ><i class='glyphicon glyphicon-bookmark'></i> (Bookmark)</span> button (far right) to add the current (front) Tab, or</li>
            <li>drag an item from a list into the Bookmarks list. Special items will have a <i class='glyphicon glyphicon-bookmark'></i> bookmark-icon which can be dragged. (Try the one next to the "Search" box in "Files".)</li>
            
            </ul></li>
        <li><b>Rename</b> a bookmark by clicking on its name and editing.</li>
        <li><b>Delete</b> a bookmark using the <span ><i class="glyphicon glyphicon-remove"></i> (Remove)</span> button</li>

    </ul>
    </p>
    <p>Note: when you delete or remove the last item from a folder, you'll be asked whether to keep the Folder. You can't delete the last item of the first folder.</p>
    <p>Tips: 
        <ul>
            <li>Try moving the <span >Files</span> folder to the top of the first list, then Save and reload Pekoe.</li>
            <li>Make only one or two changes before Saving or Reverting.</li>
            <li >Hold down the command (Mac) or Control (Win) -key and click on an item in the Files list to open it in a new Tab</li>
            <li>You can't add a Tab to a Bookmark list if it's already there.</li>
            <li>Can't drag an existing bookmark into a new Folder. Must save first.</li>
            <li>Can't rename a folder. Create a new one, Save, then drag items into it.</li>
        </ul>
    </p>
    <h3>Bookmarks and tabs behaviour</h3>
     <div>Clicking a bookmark:
             <ul>
                 <li>will open a tab (unless it's already open)</li>
                 <li>will switch to the tab if it's open but not in front</li>
                 <li>will reload a tab if it's open and in front</li>
                 
             </ul>
        </div>
        <p>Clicking a tab title will activate it and refresh the current page if it's a list.</p>
    </div>
    <h2>Lists</h2>
    <p>When you double-click any <span class='xml' >xml-file</span> a new tab will be opened for that item.
    </p>
    <p>Templates provide different views of the data.</p>
    <h2>Forms</h2>
    <p>When you double-click a Job file (xml), it will open in Pekoe Form. To edit the data, you'll need to find an appropriate Template
    from the Template Selector. Applicable Templates will be highlighted - you may need to click on a subsection to find the one you want.  </p>
    <p>The template determines the which fields you'll see in the form.</p>
</div>
</body>
</html>

};

()