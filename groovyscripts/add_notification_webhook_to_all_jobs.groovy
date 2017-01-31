// You need to install the Notification plugin for this script to work!
// https://wiki.jenkins-ci.org/display/JENKINS/Notification+Plugin

import com.tikal.hudson.plugins.notification.HudsonNotificationProperty
import com.tikal.hudson.plugins.notification.Endpoint
import com.tikal.hudson.plugins.notification.Protocol
import com.tikal.hudson.plugins.notification.Format


Boolean DRYRUN = true
String URL = "https://telegrambot.moodle.org/hubot/jenkinsnotify"

for (item in Hudson.instance.items) {

    // Decide how many log lines to send in notifications, note that the
    // last 2 are always related to the failure (and stripped by notification
    // recieved), so this is really 3 lines by defualt.
    Integer loglines = 5;

    if (item.name.contains('phpunit')) {
        // Usually useful info about failure, give
        // a bit more context:
        loglines = 10;
    } else if (item.name.contains('behat')) {
        // Can't get useful summary out of behat.
        loglines = 0;
    } else if (item.name.contains('Check upgrade savepoints')) {
        // Doesn't provide a useful summary at the moment
        loglines = 0;
    }

    // Remove existing notification configuration
    item.properties.each{
        if (it.value instanceof com.tikal.hudson.plugins.notification.HudsonNotificationProperty) {
            if (DRYRUN) {
                println("WOULD remove existing notifier from $item.name");
            }  else {
                println("Removing existing notifier from $item.name")
                item.removeProperty(it.value);
            }
        }
    }

    // Add new notification configuration
    ArrayList<Endpoint> es = new ArrayList<Endpoint>()
    es.add(new Endpoint(Protocol.HTTP, URL, 'completed', Format.JSON, 30000, loglines))
    JobProperty p = new HudsonNotificationProperty(es)
    assert(p != null)
    if (DRYRUN) {
        println("WOULD add notifier to $item.name with $loglines logliness");
    }  else {
        item.addProperty(p)
        println("Added notifier to $item.name with $loglines logliness");
    }
}
