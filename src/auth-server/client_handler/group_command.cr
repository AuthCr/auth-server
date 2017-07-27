class Auth::Server::ClientHandler
  module GroupCommand
    extend self

    def add(context, params)
      group, perm, path = params.split ' ', 3
      context.groups[group][path] = Acl::PERM_STR[perm]
      context.send_success
    end

    private def remove_path(context, group, path)
      group = context.groups[group]?
      group.delete path if group
      context.send_success
    end

    private def remove_group(context, group)
      context.groups.delete group
      context.send_success
    end

    def remove(context, params)
      splitted_params = params.split ' ', 2
      group = splitted_params[0]
      path = splitted_params[1]?
      path ? remove_path(context, group, path) : remove_group(context, group)
    end

    def list(context, params)
      context.send_success context.groups.groups.keys.inspect
    end

    def list_perms(context, params)
      perms = context.groups[params]?
      if perms
        context.send_success perms.permissions.map{|k,v| {k.to_s, v.to_s} }.to_h.inspect
      else
        context.send_success "{}"
      end
    end
  end
end
