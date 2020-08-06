

module SynchronizationLib
    
    FINAL_OD = [0.0003, 0.00015, 0.000075]
    FINAL_OUTPUT_VOL = 1#mL
    ROWS = ('A'..'H').to_a
    COLS = (1..12).to_a
    
    
    def sync_experimental_cultures(in_collection, out_collection, input_plate_ods, bio_reps)
        # Coordinates of wells in input collection that have experimental cultures
        # input_cult_coords = in_collection.get_non_empty.select {|r,c| r != 7 && !in_collection.matrix[r][c].nil?}
        input_cult_coords = in_collection.get_non_empty.select {|r,c| r != 7}
        # log_info 'input_cult_coords', input_cult_coords, in_collection.get_non_empty
        
        # Create an array of ods from non empty wells
        input_plate_ods = input_cult_coords.map {|r, c| input_plate_ods[r][c]}
        # log_info 'input_plate_ods', input_plate_ods
        
        # Calculates the average OD by slices of 6 wells - PlateReaderMethods
        average_ods = average_ods(input_cult_coords, input_plate_ods, bio_reps) # bio_rep well average ODs of plate
        # log_info 'average ods', average_ods
        
        # Calculates volumes from culture and media to obtain necessary final OD 
        ave_cult_vols_ul, ave_media_vols_ul = ave_cult_media_vol(average_ods) # 6 well average vols
        # log_info 'ave_cult_vols_ul', ave_cult_vols_ul
        # log_info 'ave_media_vols_ul', ave_media_vols_ul
        
        # Creates a matrix based on the length of row averages and number of wells measured - Used to display volumes for tech
        cult_vol_mat = matrix_mapping(input_plate_ods, ave_cult_vols_ul, bio_reps)
        media_vol_mat = matrix_mapping(input_plate_ods, ave_media_vols_ul, bio_reps)
        # log_info 'cult_vol_mat', cult_vol_mat
        # log_info 'media_vol_mat', media_vol_mat
        
        # 4. Calc true ODs based on cult_vol_ul and original ODs
        # Calculates the actual OD of each well based on the input well/cult OD and the average cult vol used for that row
        actual_ods_mat = actual_ods(input_plate_ods, ave_cult_vols_ul, bio_reps)
        # log_info 'actual_ods_mat', actual_ods_mat
            
        # 5. Associate new actual ODs to output collection - t = 0
        associate_true_ods_item(out_collection, actual_ods_mat)
        
        out_collection.matrix = out_coll_samp_id_mat(in_collection)
        
        
        return input_cult_coords, cult_vol_mat, media_vol_mat
    end

    # This function directs tech to pre-fill deep well plate with required media
    #
    # @params out_coll [collection obj] the output collection object
    # @params type_of_media [string] describes the type of media to be used in the experiment
    # @params media_vol_mat [2-D Array] is a matrix of the media volume per well in ul 
    def aliquot_media(out_coll, media_vol_mat, media)
        # Direct tech to fill output plate with media
        tot_media_vol = 0
        # show do
        #     title 'media vol mat - aliquot_media()'
        #     note "#{media_vol_mat}"
        # end
        media_vol_mat.flatten.select {|vol| vol != -1 }.each {|vol|
            tot_media_vol += vol if vol
        }
        
        rc_list = out_coll.get_non_empty.select {|r,c| !out_coll.matrix[r][c].nil? }
        log_info 'rc_list sync lib', rc_list
        show do
            title "Filling New 96 Deep Well Plate #{out_coll}"
            separator
            note "For this step you will need:"
            check "96 Well Deep U-bottom Plate and label with <b>#{out_coll.id}</b>"
            check "Multichannel Reservoir"
            check "Breathable AeraSeal Plate Cover"
            check "<b>#{((tot_media_vol/1000) + 1).round(1)}mLs</b> of <b>#{media}</b> liquid growth media."
        end
        show do
            title "Filling 96 Deep Well Plate #{out_coll}"
            separator
            note "Follow the table bellow to aliquot the appropriate amount of <b>#{media}</b> media to the respective well:"
            table highlight_alpha_rc(out_coll, rc_list) { |r, c| "#{(media_vol_mat[r][c]).round(1) if media_vol_mat[r][c]} µl" }
        end
    end
    
    # Directs tech and inoculates output collection with cultures from the input collection
    #
    # @param in_coll [collection obj] the input collection
    # @param out_coll [collection obj] the output collection
    # @param input_cult_coords [Array] one dimensional array that contains the coordinates of the input collection cultures
    # @param cult_vol_mat [2-D Array] matrix that contains the volume required to inoculate the output collection
    def inoculate_plate(in_coll, out_coll, input_cult_coords, cult_vol_mat)
        # Creates a matrix with row column coordinates from the input collection - Will be used to direct tech which input wells to dilute in the output collection
        in_out_map = input_cult_coords.map {|r, c| (ROWS[r] + COLS[c].to_s)}.select {|coord| !coord.include? "H"} # [0,0] --> "A1"
        in_out_map_mat = FINAL_OD.map {|f_od| in_out_map }.flatten.each_slice(12).to_a
        in_out_map_mat.each {|arr| 
            if arr.length != 12
                (12-arr.length).times do
                    arr.push(-1)
                end
            end
        }
        if in_out_map_mat.length != 8
            (8 - in_out_map_mat.length).times do
                in_out_map_mat.push(Array.new(12) {-1})
            end
        end
        
        # Adding alpha numeric coordinates for controls 
        input_control_cults_coords = []
        input_control_cults_coords.push(find_input_wt_cult_coord(collection=in_coll).map {|r, c| (ROWS[r] + COLS[c].to_s)}.first) # Creating 2 WT control cultures
        input_control_cults_coords.push(find_input_wt_cult_coord(collection=in_coll).map {|r, c| (ROWS[r] + COLS[c].to_s)}.first)
        gfp_control_coord = 'H9'
        input_control_cults_coords.push(gfp_control_coord)
        # input_control_cults_coords.each {|control_coord| in_out_map_mat[in_out_map_mat.length - 1].push(control_coord)}
        # in_out_map_mat.push(input_control_cults_coords)
        in_out_map_mat[7][6] = input_control_cults_coords[0]
        in_out_map_mat[7][7] = input_control_cults_coords[1]
        in_out_map_mat[7][8] = input_control_cults_coords[2]
        display_coords = out_coll.get_non_empty.select {|r,c| !out_coll.matrix[r][c].nil? }.each_slice(in_out_map.select{|coord| !coord.include? "H"}.length).to_a
        
        # Diluting cultures 1:10 before transfering
        show do
            title "Dilute Cultures in Item #{in_coll}"
            separator
            check "Perform a 1:10 dilution on cultures"
            bullet "10ul of culture to 90ul of media"
        end
        if debug
            show do
                title "Debugging"
                note "out_coll_#{out_coll}"
                note "display_coords_#{display_coords}"
                note "in_out_map_mat_#{in_out_map_mat}"# ***
                note "cult_vol_mat_#{cult_vol_mat}"
            end
        end

        display_coords.each do |rc_list|
            show do
                title "Innoculating New 96 Deep Well Plate #{out_coll}"
                separator
                bullet "The coordinates correspond to wells from 96 Flat Bottom Plate <b>#{in_coll.id}</b>."
                note "Follow the table below to inoculate the filled 96 Deep Well Plate with the appropriate volume and culture:"
                table highlight_alpha_rc(out_coll, rc_list) {|r, c| "#{in_out_map_mat[r][c] if in_out_map_mat[r][c]}\n#{cult_vol_mat[r][c].round(1) if cult_vol_mat[r][c]}µl"}
            end
        end
        
        group_by_collection = operations.map.group_by {|op| op.input("96 Well Flat Bottom").collection}
        growth_temperature = group_by_collection[in_coll].first.input("Growth Temperature (°C)").val
        Item.find(out_coll.id).associate('growth_temperature', growth_temperature)
        # Move output plate (96DW Plate to incubator)
        out_coll.location = "#{growth_temperature}C Incubator Shaker @ 800 rpm"
        out_coll.save
    ### IF USING THE SAME PLATE FOR MULTIPLE SYNCS THEN WHEN SHOULD WE DELETE INCOLLECTION
        # in_coll.mark_as_deleted
        release([out_coll], interactive: true)
        
    end    

    
    
    # Based on the number of diltuions (Final ODs) create a new matrix with sample ids in the correct organization 
    #
    # @params in_coll [collection] the input collection in order to obtain the sample id matrix
    # @return out_samp_id_mat [2-D Array] matrix containing new sample id matrix; spread out input collection sample ids
    def out_coll_samp_id_mat(in_coll)
        if debug
            in_coll = Collection.find(411551)
        end
        output_samp_ids = []
        (FINAL_OD.length).times do 
            in_coll.matrix.each_with_index do |row, r_idx|
                row.each_with_index do |well, c_idx|
                    if !well.nil?
                        if r_idx != 7
                            well > -1 ? output_samp_ids.push(well) : -1
                        end
                    end
                end
            end
        end
        # Filling in blank/empty wells with -1
        out_samp_id_mat = output_samp_ids.each_slice(12).to_a
        out_samp_id_mat.each {|row|
            if row.length != 12
                (12 - row.length).times do
                    row.push(-1)
                end
            end
        }
        if out_samp_id_mat.length != 8
            (8 - out_samp_id_mat.length).times do
                out_samp_id_mat.push(Array.new(12) {-1})
            end
        end
        return out_samp_id_mat
    end



    # Finds volume needed from input culture and the necessary media volume for the output culture/well
    #
    # @params row_od_aves [array] array of the average ODs by row
    # @return cult_vols_ul [array] array of culture volumes found based on the average row ods
    # @return media_vols_ul [array] array of media minus the culture volume
    def ave_cult_media_vol(row_od_aves)
        cult_vols_ul = []
        media_vols_ul = []
        FINAL_OD.each do |f_od|
            c_vol = row_od_aves.map {|ave_od| ave_od == 0.0 ? 0.0 : ((f_od * FINAL_OUTPUT_VOL)/ave_od) * 10000.0} # 10,000 includes the 1:10 dilution
            m_vol = c_vol.map {|vol| vol == 0.0 ? 0.0 : (1000.0 - vol).round()}
            cult_vols_ul.push(c_vol)
            media_vols_ul.push(m_vol)
        end
        return cult_vols_ul, media_vols_ul
    end
    
    # Averages 2-D array across rows. Turns 2-D array into 1-D array of averages
    #
    # @param input_plate_ods [2-D Array] matrix containing the ODs of a 96 well plate measured on the BioTek Plate Reader
    # @param 
    # @return row_od_aves [Array] array of averages across rows of the input matrix 
    def average_ods(input_cult_coords, input_plate_ods, bio_reps)
        # slice = 6
        average_ods = []
        input_plate_ods.each_slice(bio_reps).to_a.map do |arr| 
            tot_od = 0.0
            arr.each {|od| tot_od += od}
            average_ods.push(tot_od/arr.length)
        end
        return average_ods
    end
    
    # Creates a matrix based on the amount of row averages and number of wells measured
    #
    # @params input_plate_ods [Array] one dimensional array of non empty wells from input collection
    # @params ave_arr [2-D Array] matrix created from ave vol calculated based on the ave od of each slice(6 wells)
    # @return matrix [2-D Array] matrix with all volumes needed for display onto a 8x12 matrix
    def matrix_mapping(input_plate_ods, ave_arr,bio_reps)
        matrix = []
        input_slices = input_plate_ods.each_slice(bio_reps).to_a
        ave_arr.each do |arr|
            input_slices.each_with_index do |slice, i|
                slice.each {|well| matrix.push(arr[i])}
            end
        end
        matrix = matrix.flatten
        if matrix.length != 96
            (96 - matrix.length).times do
                matrix.push(-1)
            end
        end
        return matrix.each_slice(12).to_a
    end
    
    # Calculates the actual OD of each well based on the input well/cult OD and the average cult vol for that row
    #
    # @params input_plate_ods [array] 1 dim array with all the ODs that were measured from the input collection
    # @params cult_vols_ul [2-D Array] a matrix of average culture volume needed to reach requested final OD
    # @return actual_ods_mat [2-D Array] a matrix of the calculated actual OD in slices of 12 to fit the 96 well format
    def actual_ods(input_plate_ods, cult_vols_ul, bio_reps)
        actual_ods = []
        well_ods_slices = input_plate_ods.each_slice(bio_reps).to_a
        cult_vols_ul.each_with_index do |ave_cult_vol, i|
            ave_cult_vol.each_with_index do |c_vol, ii|
                well_ods_slices[ii].each {|w_od| actual_ods.push(((w_od * (c_vol/1000.0))/FINAL_OUTPUT_VOL).round(6))}
            end
        end
        actual_ods_mat = actual_ods.each_slice(12).to_a
        return actual_ods_mat
    end
    
    # Averages 2-D array across rows. Turns 2-D array into 1-D array of averages
    #
    # @param input_plate_ods [2-D Array] matrix containing the ODs of a 96 well plate measured on the BioTek Plate Reader
    # @param 
    # @return row_od_aves [Array] array of averages across rows of the input matrix 
    def average_ods(input_cult_coords, input_plate_ods, bio_reps)
        # slice = 6
        average_ods = []
        input_plate_ods.each_slice(bio_reps).to_a.map do |arr| 
            tot_od = 0.0
            arr.each {|od| tot_od += od}
            average_ods.push(tot_od/arr.length)
        end
        return average_ods
    end
    
    # given a r,c from one of the first 30 wells and an od level, figures out the location
    # of the replicate on the output plate
    def get_rc_out_from_rc_in_and_od_no(r,c,od, num_input_samples)
        absolute_rc = r * 12 + c
        if absolute_rc > 30
            raise "rc in is not one of the first 30 samples"
        end
        
        adjusted_absolute = absolute_rc + od * num_input_samples
        
        r_out = adjusted_absolute / 12
        c_out = adjusted_absolute % 12
        return r_out, c_out
    end

    def get_bio_reps_from_outgrowth_plate(collection)
        if debug
            return 3
        else
            return Item.find(collection.id).get('bio_reps')
        end
    end


end #Module

