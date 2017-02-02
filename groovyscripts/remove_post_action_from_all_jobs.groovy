// Iterate over all the Freeform jobs in a Jenkins server
// deleting a given (full class name) post-build action (also called publisher)
// The script will fail if the PUBLISHER_TO_KILL plugin/class is not installed
import hudson.model.FreeStyleProject
import hudson.model.Hudson
import hudson.tasks.Publisher

Boolean DRYRUN = true
Class PUBLISHER_TO_KILL = hudson.plugins.jabber.im.transport.JabberPublisher

for (item in Hudson.instance.items) {

    println("Job: $item.displayName")
    modified = false

    if (Hudson.instance.getJob(item.displayName).getClass() != FreeStyleProject ) {
        println("Skipped: $item.displayName")
        continue
    }

    FreeStyleProject project = Hudson.instance.getJob(item.displayName)
    List<Publisher> publishers = project.getPublishersList()

    for (publisher in publishers) {
        classname = publisher.getClass()
        if (classname.equals(PUBLISHER_TO_KILL)) {
            if (DRYRUN) {
                println("    - $PUBLISHER_TO_KILL.name WOULD be deleted (DRYRUN enabled)")
            } else {
                publishers.remove(publisher)
                println("    - $PUBLISHER_TO_KILL.name DELETED")
            }
            modified = true
        }
    }
    if (!DRYRUN && modified) {
        project.save()
        println("    - Job saved")
    }
}
