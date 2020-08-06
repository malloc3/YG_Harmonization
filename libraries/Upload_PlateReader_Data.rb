# By: Eriberto Lopez
# elopez3@uw.edu

# This library contains functions that aid in uploading data that comes from yeast high throughput screening measurements
# Ie: Plate reader measurements
needs 'Standard Libs/MatrixTools'
needs 'Standard Libs/AssociationManagement'
module Upload_PlateReader_Data
    require 'csv'
    require 'open-uri'
    include MatrixTools
    include AssociationManagement
    
    # Takes in a csv upload file in a tabular format, extracts the information on it
    # into a datamatrix object which is returned.
    # Specificly tuned to the output file of the biotek plate reader.
    #
    # @param upload [Upload]  the object which can be resolved to calibration csv
    # @return [WellMatrix]  a WellMatrix holding the measurement for each well
    def extract_measurement_matrix_from_csv(upload)
        url = upload.url
        table = []
        CSV.new(open(url)).each { |line| table.push(line) }
        dm = WellMatrix.create_empty(96, -1) if table.size > 25
        dm = WellMatrix.create_empty(24, -1) if table.size <= 25
        table.each_with_index do |row, idx|
          next if idx.zero?
          well_coord = row[2]
          next if well_coord.nil?
          measurement = row[3].to_f
          next if measurement.nil?
          dm.set(well_coord, measurement)
        end
        dm
    end
    
  # Returns the average OD measurement for different dilutions and well volumes.
  # The plotted result of this method can be fit to a curve
  # to be used for calibrating the plate reader. This is very specific to the
  # Eriberto's calibration of the biotek plate reader.
  #
  # @param upload [Upload]  the object whihc can be resolved to calibration csv
  # @return [Hash]  a hash containing averaged measurements for
  #  					every concentration and volume tested
    def get_calibration_data_hash(upload)
        method = upload.name
        dm = extract_measurement_matrix_from_csv(upload)
        result = {}
        data_by_conc = Hash.new { |h, key| h[key] = [0, 0] }

        if method.include? 'gfp'
            # show {note "#{method}"}
            starting_concentration = 50.0#uM
            # first 4 rows are serial dilutions
            for i in 0...4
              12.times do |j|
                # each column is a 2x dilution of the previous, starting at 50uM
                this_conc = starting_concentration / (2**j)
                data = data_by_conc[this_conc]
                data[0] += dm[i, j].to_f
                data[1] += 1
                data_by_conc[this_conc] = data
              end
            end
            # add serial dilution averages to result hash
            data_by_conc.each_key do |k,|
              data = data_by_conc[k]
              result[k] = data[0] / data[1]
            end
            return result
        elsif method.include? 'od'
            # row 5, 6 are lud dilutions and pure solution respectively
            for i in 4...6
                for j in 0...4
                    data_by_conc["100_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["100_#{i}"][1] += 1
                end
                for j in 4...8
                    data_by_conc["200_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["200_#{i}"][1] += 1
                end
                for j in 8...12
                    data_by_conc["300_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["300_#{i}"][1] += 1
                end
            end
            # add lud averages to result hash
            for i in 1..3
              lud_avg = data_by_conc["#{i}00_4"][0] / data_by_conc["#{i}00_4"][1]
              sol_avg = data_by_conc["#{i}00_5"][0] / data_by_conc["#{i}00_5"][1]
              result["lud#{i}00"] = (lud_avg - sol_avg).round(5) # Returns blanked averages
            end
        end
        result
    end

    # Provides a upload button in a showblock in order to upload a single file
    #
    # @params upload_filename [string] can be the name of the file that you want tech to upload
    # @return up_show [hash] is the upload hash created in the upload show block
    # @return up_sym [symbol] is the symbol created in upload show block that will be used to access upload
    def upload_show(upload_filename)
        upload_var = "file"
        up_sym = upload_var.to_sym
        up_show = show do
            title "Upload Your Measurements"
            note "Select and Upload: #{upload_filename}"
            upload var: "#{upload_var}"
        end
        return up_show, up_sym
    end
    
    # Retrieves the upload object from upload show block
    #
    # @params up_show [hash] is the hash that is created in the upload show block
    # @params up_sym [symbol] is the symbol created in the upload show block and used to access file uploaded
    # @return upload [upload_object] is the file that was uploaded in the upload show block
    def find_upload_from_show(up_show, up_sym)
        # Makes a query to find the uploaded file by its default :id
        upload = up_show[up_sym].map {|up_hash| Upload.find(up_hash[:id])}.shift 
        return upload
    end
    
    # Associates an upload to an item - DEPRCIATED
    # #
    # # @params collection [collection obj] can be the collection that you wish to associate upload to
    # # @params upload [upload_obj] the file that you wish to associate to item
    # # @params key [string] the key to the association it will also appear as description when looking at item
    # def associate_to_item(collection, upload, key)
    #     Item.find(collection.id).associate key.to_sym, "item_#{collection.id}", upload
    # end
    # Associates an upload to an item
    #
    # @params in_obj [obj] can be the collection that you wish to associate upload to
    # @params upload [upload_obj] the file that you wish to associate to item
    # @params key [string] the key to the association it will also appear as description when looking at item
    def associate_to_item(in_obj, key, upload)
        item_assoc = AssociationMap.new(in_obj)
        item_assoc.put(key.to_sym, upload)
        item_assoc.save
    end

    
    # Associates an upload to the plan that it was uploaded in - Still needed for YG_Harmonization calibration associations
    #
    # @params upload [upload_obj] the file that you wish to associate to plan
    # @params key [string] the key to the association it will also appear as description when looking at item
    def associate_to_plan(upload, key)
        plan = operations.map {|op| op.plan}.first
        plan.associate key.to_sym, "plan_#{plan.id}", upload
    end    
    # Associates an upload to the plans that it was uploaded in
    #
    # @params data [obj] the thing that you wish to associate to plan
    # @params key [string] the key to the association it will also appear as description when looking at item
    def associate_to_plans(key, data) 
        # iterate over ops, find all unique plans, associate to each plan, ensure copying
        plans = operations.map { |op| op.plan }.uniq
        plans.each do |plan|
            plan_associations = AssociationMap.new(plan)
            plan_associations.put(key.to_sym, data)
            plan_associations.save
        end
    end    
    
    # Opens file using its url and stores it line by line in a matrix
    #
    # @params upload [upload_obj] the file that you wish to read from
    # @return matrix [2D-Array] is the array of arrays of the rows read from file, if csv
    def read_url(upload)
        url = upload.url
        matrix = []
        CSV.new(open(url)).each {|line| matrix.push(line)}
        # open(url).each {|line| matrix.push(line.split(',')}
        return matrix
    end

    
    # Takes csv matrix and formats data for OD measurements - Biotek Plate reader
    #
    # @params matrix [2D-Array] can be array of arrays containing od measurements 
    # @return hash [hash] is hash created from matrix parameter
    def matrix_to_hash(matrix)
        hash = Hash.new(0)
        cols = matrix.shift.select {|col| col != nil}
        rows = []
        data = []
        ods = matrix.map do |arr|
            rows.push(arr.shift) # first index is row letter
            arr.pop() # Strips off last index
            arr.map! {|str| str.to_f} # converts strings to float to include dilution factor
            data.push(arr)
            arr.map {|od| od} # Good place to include dilution factor
        end
        hash["cols"] = cols
        hash["rows"] = rows
        hash["data"] = data
        # hash["optical_density"] = ods
        return hash
    end

    
    # Reads uploaded file and associates data to a given item/collection
    #
    # @params upload [upload obj] upload (csv) that is going to be read and processed
    # @params collection [collection obj] collection that the data will be associated to
    # @params method [string] the type of measurement that was taken (od or gfp)
    # @params timepoint [integer] the number of hours that data was collected at
    def associate_PlateReader_Data(upload, collection, method, timepoint)
        up_name = upload.name.downcase
        up_ext = up_name.split('.')[1]
        if up_ext.downcase == 'csv'
            # If calibration measurement will be associated with item and plan
            collection_associations = AssociationMap.new(collection)
            if up_name.include? 'cal'
                key = method == 'cal_gfp' ? 'cal_fluorescence' : 'cal_optical_density'
                
                cal_hash = get_calibration_data_hash(upload) # from BiotekPlateReader Lib
                data_hash = Hash.new(0)
                if method == 'cal_gfp'
                    # Fluorescence std curve & r-sq value
                    slope, yint, x_arr, y_arr = gfp_standard_curve(cal_hash)
                    r_sq = r_squared_val(slope, yint, x_arr, y_arr)
                    trendline = "y = #{slope}x + #{yint}  (R^2 = #{r_sq})"
                    # Associating flour calibration data hash
                    
                    data_hash['uM_to_data'] = cal_hash
                    collection_associations.put(key, data_hash)
                    # ie: 'cal_fluorescence' : {'uM_to_data'=>{50=>2400,25=>1234...}}
                    collection_associations.put('Fluorescence Standard Curve', trendline)
                    associate_to_plans('Fluorescence_Standard_Curve', trendline)
                else
                    correction_val_hash = ludox_correction_factors(cal_hash)
                    data_hash['vol_to_correction_factor'] = correction_val_hash
                    collection_associations.put(key, data_hash) # ie: 'cal_od'=>{'vol_to_correction_factor'=>{"100"=>1.88,"200"=>0.955}}
                    associate_to_plans('vol_to_correction_factor', correction_val_hash)
                end
                
            else
                # matrix = read_url(upload)
                matrix = (extract_measurement_matrix_from_csv(upload)).to_a # Uses BiotekPlateReaderCalibration/PlateReaderMethods
                # hash = matrix_to_hash(matrix) # Upload_Data Lib - May change if I change data format
                log_info 'csv matrix', matrix
                # take hash and slice up to associate to input collections - that way matrix always gets formatted to the same dimensions as in_collection
                in_cols = collection.object_type.columns
                in_rows = collection.object_type.rows
                
                # 'data' - known beforehand, created in matrix_to_OD_hash(matrix)
                # slices = hash['data'].flatten.each_slice(in_cols).map {|slice| slice} # 2-D Array with similar dims as collection
                slices = matrix.flatten.each_slice(in_cols).map {|slice| slice} # 2-D Array with similar dims as collection
                log_info 'sliced up csv', slices
                
                #### left off here attempting to create hashes for GFP or optical density at differnet timepoints if necessary
                key = method == 'od' ? 'optical_density': 'gfp_fluorescence'
                data_hash = collection_associations.get(key)
                log_info slices.shift(in_rows)
                if data_hash.nil? 
                    data_hash = Hash.new(0)
                    data_hash["#{timepoint}_hr"] = slices.shift(in_rows)
                    collection_associations.put(key, data_hash)
                else
                    data_hash["#{timepoint}_hr"] = slices.shift(in_rows)
                    collection_associations.put(key, data_hash)
                end
            end
            collection_associations.save
        end
        # should produce ie: 'optical_density': {'16h_od'=>[[][][][]...[]]}
    end

    
    # For associating a matrix to an item
    #
    # Associatition skem: key:{ desc:[mat] }
    # @params item [object] item object that data will be associated to
    # @params key [string] key to the data hash associated to the item 
    # @params desc [string] describes the certain matrix data that it is pair with in the data hash
    # @params mat [2D-Array] is the matrix of data being associated
    def associate_mat_to_item(item, key, desc, mat)
        hash = Hash.new(0)
        data_hsh = hash[desc] = mat
        item.associate(key, data_hsh)
    end
        # This fuction uses a reference od600 measurement to calculate the correction factor for different vols (100ul, 200, 300)
    # 
    # @params hash [hash] is the hash of averaged blanked LUDOX samples at different volumes
    # 
    # @returns correction_val_hash [hash] is the hash containing the correction factor for the optical density (600nm) for this experiment
    def ludox_correction_factors(hash)
        ref_od600 = 0.0425 #Taken from iGEM protocol - is the ref val of another spectrophotometer
        # ref/corrected vals
        correction_val_hash = Hash.new(0)
        hash.each do |vol, ave|
            correction_val_hash[vol[3..6]] = (ref_od600/ave).round(4)
        end
        return correction_val_hash
    end
  
    # This function creates a standard curve from the flourocein calibration plate
    #
    # @params coordinates [hash or 2D-Array] can be a hash or [[x,y],..] where x is known concentration & y is measurement of flouroscence
    #
    # @returns slope [float] float representing the slope of the regressional line
    # @returns yint [float] float representing where the line intercepts the y-axis
    # @returns x_arr [Array] a 1D array for all x coords
    # @returns y_arr [Array] a 1D arrya for all y coords
    def gfp_standard_curve(coordinates)
        # Calculating Std Curve for GFP
        num_of_pts = 0
        a = 0
        x_sum = 0
        y_sum = 0
        x_sq_sum = 0
        x_arr = []
        y_arr = []
        coordinates.each do |x, y|
            if x < 25 # Above 25uM is out of linear range of our instrument
                a += (x * y)
                x_sum += x
                x_sq_sum += (x**2)
                y_sum += y
                x_arr.push(x)
                y_arr.push(y)
                num_of_pts += 1
            end
        end
        a *= num_of_pts
        b = x_sum * y_sum
        c = num_of_pts * x_sq_sum
        d = x_sum**2
        slope = (a - b)/(c - d)
        f = slope * (x_sum)
        yint = (y_sum - f)/num_of_pts
        # show{note "y = #{(slope).round(2)}x + #{(yint).round(2)}"}
        return (slope).round(3), (yint).round(3), x_arr, y_arr
    end
    
    # This function calculates how much deviation points are from a regressional line - R-squared Value 
    # The closer it is to 1 or -1 the less deviation theres is
    #
    # @params slope [float] float representing the slope of the regressional line
    # @params yint [float] float representing where the line intercepts the y-axis
    # @params x_arr [Array] a 1D array for all x coords
    # @params y_arr [Array] a 1D arrya for all y coords
    #
    # @returns rsq_val [float] float representing the R-squared Value
    def r_squared_val(slope, yint, x_arr, y_arr)
        y_mean = y_arr.sum/y_arr.length.to_f
        # Deviation of y coordinate from the y_mean
        y_mean_devs = y_arr.map {|y| (y - y_mean)**2}
        dist_mean = y_mean_devs.sum # the sq distance from the mean
        # Finding y-hat using regression line
        y_estimate_vals = x_arr.map {|x| (slope * x) + yint }
        # Deviation of y-hat values from the y_mean
        y_estimate_dev = y_estimate_vals.map {|y| (y - y_mean)**2}
        dist_regres = y_estimate_dev.sum # the sq distance from regress. line
        rsq_val = (dist_regres/dist_mean).round(4)
        return rsq_val
    end

end # Module