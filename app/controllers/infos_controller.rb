class InfosController < ApplicationController
  def index
    @goods = Goods.all
    @total_spend = current_user.total_spend
    @orders_count = current_user.orders.count
    @notices = Notice.all
  end

  def l_infos
    @l_users = current_user.low_level_users
  end
end
