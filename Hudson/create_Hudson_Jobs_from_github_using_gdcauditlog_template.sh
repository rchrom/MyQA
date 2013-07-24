for job in `perl github-list.pl | grep gooddata | awk '{print $1}' | grep -v gdc-auditlog`; do
	perl clone_hudson_job.pl -to $job;
done