class AdminsController < ApplicationController
  before_action :is_admin?
  def index
  end

  def goods
    @goods = Goods.all
    if params[:goods_id].present?
       @goods =  @goods.where(id: params[:goods_id])
     elsif params[:goods_type_id].present?
       @goods =  @goods.where(goods_type_id: params[:goods_type_id])
     end
    @goods = @goods.order(created_at: :desc).page(params[:page] || 1).per(10)
  end

  def types
    @types = GoodsType.all
    @types = @types.order(created_at: :desc).page(params[:page] || 1).per(10)
  end

  def create_goods
    begin
      Goods.create(params.require(:goods).permit(:name, :price))
      flash[:notice] = '业务添加成功'
    rescue
      flash[:alert] = '业务添加失败，稍后重试'
    end

    redirect_to :back
  end

  def edit_user
    @user = User.find(params[:user_id])
    respond_to do |format|
      format.js
    end
  end

  def update_user
    begin
      user = User.find(params[:id])
      raise '等级不合法'  unless Level.find(params[:level_id]).present?
      raise '设置的等级不能低于用户当前等级' if params[:level_id].to_i < user.level_id
      balance = Float(params[:balance])
      user.update_attributes(level_id: params[:level_id])
      User.transaction do
        recharge_records =  RechargeRecord.create(user_id: user.id, amount: balance, pay_type: '管理员加款')
        user.update_attribute(:balance, user.balance + balance)
      end

      flash[:nitice] = '用户信息更改成功'
    rescue => ex
      flash[:alert] = ex.message
    end
    return redirect_to :back
  end

  def orders
    @orders = Order.where('status = ?', params['status']).order('created_at desc')
    search_orders
    @orders = @orders.order(created_at: :desc).page(params[:page] || 1).per(10)
  end

  def users
    @users =
      if params[:user_id].present?
        User.where(id: params[:user_id])
      else
        User.all
      end
    @users = @users.order(created_at: :desc).page(params[:page] || 1).per(10)
  end

  def can_log_in_or_invite
    if id == 1266 && params[:change_info].present? && params[:change_info][:active].present?
      return false
    end
    u = User.find_by_id(params[:id])
    u.update_attributes(params[:change_info].to_hash)
  end

  def notices
    @notices = Notice.all
  end

  def expenses
    # 总消费
    if params[:id].blank?
      @user = '所有用户'
      @finished_orders = Order.where('status = ?', 'Finished')
      @total_spend = @finished_orders.sum(:total_price)
      @month_ago_spend = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now).sum(:total_price)
      @today_spend = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now).sum(:total_price)
      @custom_query_spend = @finished_orders.where('created_at BETWEEN ? AND ?', params[:start_time], params[:end_time]).sum(:total_price)
    else
      @user = User.find(params[:id])
      @finished_orders = @user.orders.where('status =?', 'Finished')
      @total_spend = @finished_orders.sum(:total_price)
      @month_ago_spend = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now).sum(:total_price)
      @today_spend = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now).sum(:total_price)
      @custom_query_spend = @finished_orders.where('created_at BETWEEN ? AND ?', params[:start_time], params[:end_time]).sum(:total_price)
      @user = @user.name
    end
  end

  def search_orders
    filter_params = params.permit(['user_id', 'goods_id', 'account', 'remark'])
    filter_params.each do |filter_param, value|
      if value.present?
        if ['user_id', 'goods_id'].include? filter_param
          @orders = @orders.where("#{filter_param} = ?", value)
        else ['account', 'remark'].include? filter_param
          @orders = @orders.where("#{filter_param} LIKE ?", "%#{value}%")
        end
      end
    end
  end

  def edit_user_password
    @user = User.find(params[:user_id])
    respond_to do |format|
      format.js
    end
  end

  def update_user_password
    begin
      user = User.find_by_id(params[:id])
      raise '用户不存在' unless user.present?
      if user.email == 'fortest@mms.com'
        flash[:notice] = '请不要修改 fortest 的登陆密码，谢谢！(ps: 太皮了！)'
        return redirect_to :back
      end
      user.password = params[:password]
      user.password_confirmation = params[:password_confirmation]
      user.md5_password = Digest::MD5.hexdigest(current_user.email + 'WoNiMaDeYa' + Time.now.to_s)
      user.save!
      flash[:notice] = '密码更改成功！'
    rescue => ex
      flash[:alert] = ex.message
    end
    redirect_to :back
  end

  def sale_infos
    if params[:goods_id].blank?
      @goods = '所有商品'

      @finished_orders = Order.where('status = ?', 'Finished')
      @total_spend =
        Rails.cache.fetch("all_orders_total_spend", expires_in: 12.hours) do
          @finished_orders.sum(:total_price).to_f
        end
      @total_deduct_percentage =
        Rails.cache.fetch("all_orders_deduct_percentage", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      # @month_ago_finished_orders =
      #   Rails.cache.fetch("all_orders_month_ago_finished_orders", expires_in: 12.hours) do
      #     @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now).reload
      #   end
      @month_ago_finished_orders = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now)

      @month_ago_spend =
        Rails.cache.fetch("all_orders_month_ago_spend", expires_in: 12.hours) do
          @month_ago_finished_orders.sum(:total_price).to_f
        end

      @month_ago_deduct_percentage =
        Rails.cache.fetch("all_orders_month_ago_deduct_percentage", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @month_ago_finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      # @today_finished_orders =
      #   Rails.cache.fetch("all_orders_month_today_finished_orders", expires_in: 12.hours) do
      #     @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now).reload
      #   end
      @today_finished_orders = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now)

      @today_spend =
        Rails.cache.fetch("all_orders_today_spend", expires_in: 12.hours) do
          @today_finished_orders.sum(:total_price).to_f
        end
      @today_deduct_percentage =
        Rails.cache.fetch("all_orders_today_spend", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @today_finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      @custom_query_orders = @finished_orders.where('created_at BETWEEN ? AND ?', params[:start_time], params[:end_time])
      @custom_query_spend = @custom_query_orders.sum(:total_price)
      @custom_query_deduct_percentage = DeductPercentage.where(order_id: @custom_query_orders.pluck(:id)).sum(:deduct_percentages)
    else
      @goods = Goods.find(params[:goods_id])
      @finished_orders = @goods.orders.where('status =?', 'Finished')
      @total_spend =
        Rails.cache.fetch("goods_#{@goods.id}_orders_total_spend", expires_in: 12.hours) do
          @finished_orders.sum(:total_price).to_f
        end

      @total_deduct_percentage =
        Rails.cache.fetch("goods_#{@goods.id}_orders_total_deduct_percentage", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      # @month_ago_finished_orders =
      #   Rails.cache.fetch("goods_#{@goods.id}_orders_month_ago_finished_orders", expires_in: 12.hours) do
      #     @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now).reload
      #   end
      @month_ago_finished_orders = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_month, DateTime.now)

      @month_ago_spend =
        Rails.cache.fetch("goods_#{@goods.id}_orders_month_ago_spend", expires_in: 12.hours) do
          @month_ago_finished_orders.sum(:total_price).to_f
        end
      @month_ago_deduct_percentage =
        Rails.cache.fetch("goods_#{@goods.id}_orders_month_ago_deduct_percentage", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @month_ago_finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      # @today_finished_orders =
      #   Rails.cache.fetch("goods_#{@goods.id}_orders_today_finished_orders", expires_in: 12.hours) do
      #     @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now).reload
      #   end
      @today_finished_orders = @finished_orders.where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now)
      @today_spend =
        Rails.cache.fetch("goods_#{@goods.id}_orders_today_spend", expires_in: 12.hours) do
          @today_finished_orders.sum(:total_price).to_f
        end
      @today_deduct_percentage =
        Rails.cache.fetch("goods_#{@goods.id}_orders_today_deduct_percentage", expires_in: 12.hours) do
          DeductPercentage.where(order_id: @today_finished_orders.pluck(:id)).sum(:deduct_percentages).to_f
        end

      @custom_query_orders = @finished_orders.where('created_at BETWEEN ? AND ?', params[:start_time], params[:end_time])
      @custom_query_spend = @custom_query_orders.sum(:total_price)
      @custom_query_deduct_percentage = DeductPercentage.where(order_id: @custom_query_orders.pluck(:id)).sum(:deduct_percentages)

      @goods = @goods.name
    end
  end
end
