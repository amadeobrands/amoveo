sync1();
function sync1() {
    document.body.appendChild(document.createElement("br"));
    document.body.appendChild(document.createElement("br"));
    var button = document.createElement("BUTTON");
    button.id = "sync_button";
    var button_text = document.createTextNode("download and share blocks");
    button.appendChild(button_text);
    button.onclick = function() {
	local_get(["sync", JSON.parse(server_ip.value), parseInt(server_port.value, 10)]);
    };
    document.body.appendChild(button);
}
