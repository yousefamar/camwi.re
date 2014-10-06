<?php
	// TODO: Consider removing hardcoded GitHub IP prefix and allowing any IP to update.
	if (strpos($_SERVER["REMOTE_ADDR"], "192.30.252.") !== 0)
		header("Location: /");

	exec("cd /home/amar/public_html/camwi.re/ && git up");

	/*
	ob_start();
	var_dump($_REQUEST["payload"]);
	$data = ob_get_clean();
	$f = fopen("update.txt", "w") or die("Unable to open file.");
	fwrite($f, "Last request from ".$_SERVER["REMOTE_ADDR"]."\n\n");
	fwrite($f, $data);
	fclose($f);
	*/
?>
