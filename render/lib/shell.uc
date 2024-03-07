/**
 * Set the root password.
 */
export function password(password) {
	if (length(password)) 
		system(`sed -i "s|^root:[^:]*|root:${password}|g" /etc/shadow`);
	else
		system('passwd -d root > /dev/null');
};
