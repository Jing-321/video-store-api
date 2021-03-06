require 'date'

class VideosController < ApplicationController

  def index
    videos = Video.all.order(:title)
    render json: videos.as_json(only: ["id", "title", "release_date", "available_inventory"]),
                                status: :ok
  end

  def show
    video = Video.find_by(id: params[:id])

    if video.nil?
      render json: {
          errors: ["Not Found"]
      }, status: :not_found

      return
    end

    render json: video.as_json(only: ["available_inventory", "overview", "release_date", "title", "total_inventory"]),
                                status: :ok
  end

  def create
    video = Video.new(video_params)
    if video.save
      render json: video.as_json(only: [:id]), status: :created
    else
      render json: {errors: video.errors.messages},
             status: :bad_request
    end
    return
  end

  def checkout
    customer = Customer.find_by(id: rental_params[:customer_id])
    video = Video.find_by(id: rental_params[:video_id])

    if customer.nil?
      render json: {errors: ["Not Found"]}, status: :not_found
      return
    elsif video.nil?
      render json: {errors: ["Not Found"]}, status: :not_found
      return
    else
      rental = Rental.new(rental_params)
      rental.due_date = Date.today + 7
    end

    if rental.video.available_inventory < 1
      render json: {errors: "There is no available inventory for this video."},
             status: :bad_request
      return
    end

    if rental.save
      customer.videos_checked_out_count += 1
      customer.save
      video.available_inventory -= 1
      video.save
      rental.reload
      render json: {
          "customer_id": rental.customer_id,
          "video_id": rental.video_id,
          "due_date": rental.due_date,
          "videos_checked_out_count": rental.customer.videos_checked_out_count,
          "available_inventory": rental.video.available_inventory
      }, status: :ok
    else
      render json: {
          "ok": false,
          errors: rental.errors.messages
      },status: :bad_request
    end
    return
  end

  def checkin
    customer = Customer.find_by(id: rental_params[:customer_id])
    video = Video.find_by(id: rental_params[:video_id])
    rental = Rental.find_by(customer_id: rental_params[:customer_id], video_id: rental_params[:video_id])

    if customer.nil?
      render json: {errors: ["Not Found"]}, status: :not_found
      return
    elsif video.nil?
      render json: {errors: ["Not Found"]}, status: :not_found
      return
    elsif rental.nil?
      render json: {errors: "Can't find the rental order."}, status: :not_found
      return
    else

      customer.videos_checked_out_count -= 1
      customer.save
      video.available_inventory += 1
      video.save
      customer.reload
      video.reload
      render json: {
          "customer_id": customer.id,
          "video_id": video.id,
          "videos_checked_out_count": customer.videos_checked_out_count,
          "available_inventory": video.available_inventory
      },status: :ok
    end
    return
  end


  private

  def video_params
    return params.permit(:id, :title, :release_date, :available_inventory, :overview, :total_inventory)
  end

  def rental_params
    return params.permit(:customer_id, :video_id, :due_date)
  end
end
